VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Apertura_Operacion"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

' --- INICIO: NUEVA SUBRUTINA ---
' Subrutina para manejar la lógica de Remesa y Manifiesto para MOTOs
Private Sub ActualizarEstadoMoto()
    If Me.txtVehiculo.Value = "MOTO" Then
        ' Si es MOTO, deshabilita y limpia los campos
        Me.txtRemesa.Enabled = False
        Me.txtManifiesto.Enabled = False
        Me.txtRemesa.Value = Null
        Me.txtManifiesto.Value = Null
    Else
        ' Para cualquier otro vehículo, los habilita
        Me.txtRemesa.Enabled = True
        Me.txtManifiesto.Enabled = True
    End If
End Sub
' --- FIN: NUEVA SUBRUTINA ---

' --- AJUSTE: Se añade la nueva subrutina central ---
Private Sub ActualizarEstadoAuxiliares()
    ' Esta subrutina centraliza la lógica para habilitar/deshabilitar los combos de auxiliares.
    
    If IsNull(Me.cmbEstacion.Value) Then
        ' Si NO hay estación seleccionada, los combos de auxiliares SIEMPRE están deshabilitados.
        Me.cmbCcauxiliar1.Enabled = False
        Me.cmbCcauxiliar2.Enabled = False
    Else
        ' Si HAY una estación, el estado de los combos depende de sus respectivos checkboxes.
        ' Esto preserva la lógica de los chkSinAux.
        Me.cmbCcauxiliar1.Enabled = Not Me.chkSinAux1.Value
        Me.cmbCcauxiliar2.Enabled = Not Me.chkSinAux2.Value
    End If
End Sub

' --- AJUSTE: Nueva subrutina que centraliza TODA la lógica de los auxiliares ---
Private Sub ActualizarLogicaCompletaAuxiliares()
    ' 1. Lógica jerárquica de habilitación de los checkboxes
    ' Si Aux 2 NO está marcado, Aux 1 DEBE estar deshabilitado y desmarcado.
    If Me.chkSinAux2.Value = False Then
        Me.chkSinAux1.Enabled = False
        Me.chkSinAux1.Value = False ' Forzar a que esté desmarcado
    Else
        Me.chkSinAux1.Enabled = True
    End If
    
    ' 2. Lógica para habilitar/deshabilitar los combos de selección (tu lógica existente)
    If IsNull(Me.cmbEstacion.Value) Then
        ' Si NO hay estación, los combos siempre están deshabilitados
        Me.cmbCcauxiliar1.Enabled = False
        Me.cmbCcauxiliar2.Enabled = False
    Else
        ' Si HAY estación, el estado de los combos depende de sus checkboxes
        Me.cmbCcauxiliar1.Enabled = Not Me.chkSinAux1.Value
        Me.cmbCcauxiliar2.Enabled = Not Me.chkSinAux2.Value
    End If
End Sub

Private Sub BTN_Borrar_Click()
    LimpiarAperturaOperacion Me
    Me.chkSinAux1 = False
    Me.chkSinAux2 = False
    ' Vuelve a cargar sectores/auxiliares dependientes de estación fija
    Call cmbEstacion_AfterUpdate
    Call ActualizarLogicaCompletaAuxiliares
    Call ActualizarEstadoMoto ' <-- AJUSTE: Llamar a la nueva lógica
End Sub

' Acciones a ejcutar boton guardar
Private Sub BTN_Guardar_Click()
    On Error GoTo ErrHandler
    Dim rsOT             As DAO.Recordset
    Dim jsonOTs          As String
    Dim sql              As String
    Dim remesaParam      As String
    Dim manifiestoParam  As String
    Dim usuarioActual    As String
    
    usuarioActual = EstablecerUsuarioActual
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual. El registro no se puede completar.", vbCritical
        Exit Sub
    End If
    
    If Not ValidarCamposObligatorios() Then Exit Sub
    
    If Not Me.chkSinAux1.Value And Not Me.chkSinAux2.Value Then
        If Me.cmbConductor.Value = Me.cmbCcauxiliar1.Value Then
            MsgBox "El ID del Conductor no puede ser igual al ID del Auxiliar 1.", vbExclamation
            Me.cmbConductor.SetFocus
            Exit Sub
        End If
        If Me.cmbConductor.Value = Me.cmbCcauxiliar2.Value Then
            MsgBox "El ID del Conductor no puede ser igual al ID del Auxiliar 2.", vbExclamation
            Me.cmbConductor.SetFocus
            Exit Sub
        End If
        If Me.cmbCcauxiliar1.Value = Me.cmbCcauxiliar2.Value Then
            MsgBox "El ID del Auxiliar 1 no puede ser igual al ID del Auxiliar 2.", vbExclamation
            Me.cmbCcauxiliar1.SetFocus
            Exit Sub
        End If
    ElseIf Me.chkSinAux1.Value And Not Me.chkSinAux2.Value Then
        If Me.cmbConductor.Value = Me.cmbCcauxiliar2.Value Then
            MsgBox "El ID del Conductor no puede ser igual al ID del Auxiliar 2.", vbExclamation
            Me.cmbConductor.SetFocus
            Exit Sub
        End If
    ElseIf Me.chkSinAux2.Value And Not Me.chkSinAux1.Value Then
        If Me.cmbConductor.Value = Me.cmbCcauxiliar1.Value Then
            MsgBox "El ID del Conductor no puede ser igual al ID del Auxiliar 1.", vbExclamation
            Me.cmbConductor.SetFocus
            Exit Sub
        End If
    ElseIf Me.chkSinAux1.Value And Me.chkSinAux2.Value Then
        If Me.cmbConductor.Value = "" Then
            MsgBox "El ID del Conductor es obligatorio cuando no hay auxiliares.", vbExclamation
            Me.cmbConductor.SetFocus
            Exit Sub
        End If
    End If
    
    If Nz(Me.txtVehiculo.Value, "") <> "MOTO" Then
        If Trim(Nz(Me.txtRemesa.Value, "")) <> "" And Trim(Nz(Me.txtManifiesto.Value, "")) <> "" Then
            If Trim(Nz(Me.txtRemesa.Value, "")) = Trim(Nz(Me.txtManifiesto.Value, "")) Then
                MsgBox "El dato de Remesa no puede ser igual al dato de Manifiesto.", vbExclamation
                Me.txtRemesa.SetFocus
                Exit Sub
            End If
        End If
    End If
    
    If Not VerificarYReconectarMySQL() Then Exit Sub
    If cnn Is Nothing Then Set cnn = New ADODB.Connection
    If cnn.State <> adStateOpen Then cnn.Open Con
    
    With Me!sub_tbl_ot_temporal.Form
        If .Dirty Then .Dirty = False
        .Requery
    End With
    
    jsonOTs = "["
    Set rsOT = Me!sub_tbl_ot_temporal.Form.RecordsetClone
    rsOT.MoveFirst
    Do Until rsOT.EOF
        jsonOTs = jsonOTs & """" & rsOT!numero_ot & """"
        rsOT.MoveNext
        If Not rsOT.EOF Then jsonOTs = jsonOTs & ","
    Loop
    rsOT.Close
    jsonOTs = Replace(jsonOTs & "]", "'", "''")
    
    If jsonOTs = "[]" Then
        MsgBox "Debe ingresar al menos una OT antes de guardar.", vbExclamation
        Exit Sub
    End If
    
    remesaParam = IIf(Nz(Me.txtRemesa.Value, "") = "", "NULL", "'" & Replace(Nz(Me.txtRemesa.Value, ""), "'", "''") & "'")
    manifiestoParam = IIf(Nz(Me.txtManifiesto.Value, "") = "", "NULL", "'" & Replace(Nz(Me.txtManifiesto.Value, ""), "'", "''") & "'")
    
    ' <<< INICIO: AJUSTE - CADENA SQL CON NUEVO PARÁMETRO >>>
    sql = "CALL insertar_operacion_completa(" & Nz(Me.cmbServicio, 0) & "," & Nz(Me.cmbDriver, 0) & ",'" & Nz(Me.txtVehiculo, "") & "'," & Nz(Me.cmbEstacion, 0) & ",'" & Format(Nz(Me.txtFecha, Date), "yyyy\-mm\-dd") & "','" & Nz(Me.cmbProveedor, "") & "'," & Nz(Me.cmbTonelaje, 0) & _
    ",'" & Replace(Nz(Me.cmbSector, ""), "'", "''") & "','" & Replace(Nz(Me.cmbPlaca, ""), "'", "''") & "','" & Format(Nz(Me.cmbHoraInicio, Time), "HH:mm:ss") & "','" & Replace(Nz(Me.txtNombreRuta, ""), "'", "''") & "','" & Nz(Me.cmbClasUsoPxH, "") & "','" & _
    Replace(Nz(Me.cmbConductor, ""), "'", "''") & "','" & Replace(Nz(Me.cmbCcauxiliar1, ""), "'", "''") & "','" & Replace(Nz(Me.cmbCcauxiliar2, ""), "'", "''") & "'," & Nz(Me.txtEnvios, 0) & "," & Nz(Me.txtKmInicial, 0) & _
    ",'" & Nz(Me.cmbTipoPago, "") & "'," & remesaParam & "," & manifiestoParam & _
    "," & Nz(Me.cmbCiudadPoblacion, "NULL") & _
    "," & IIf(IsNull(Me.txtConsecutivo), "NULL", Me.txtConsecutivo) & "," & IIf(IsNull(Me.txtValor), "NULL", Me.txtValor) & _
    ",'" & jsonOTs & "','" & usuarioActual & "'" & _
    ");"
    ' <<< FIN: AJUSTE >>>
    
    cnn.Execute sql
    
    Dim estacionSeleccionada As Variant
    estacionSeleccionada = Me.cmbEstacion.Value
    Call LimpiarAperturaOperacion(Me)
    Me.chkSinAux1 = False
    Me.chkSinAux2 = False
    
    Call ActualizarLogicaCompletaAuxiliares
    Call ActualizarEstadoCamposPago
    
    Me.cmbEstacion.Value = estacionSeleccionada
    Me.cmbEstacion.Requery
    Call cmbEstacion_AfterUpdate
    
    If Not IsNull(Me.cmbEstacion) Then
        Me.cmbSector.RowSource = "SELECT sector_id, sector, contrato FROM vista_sectores_deprisa WHERE base_id = " & Me.cmbEstacion & " ORDER BY sector;"
        Me.cmbSector.Requery
    End If
    MsgBox "Operación y OTs registradas correctamente.", vbInformation
    
    Call RequeryAllDataControls(Me)
    
    Exit Sub
ErrHandler:
    If InStr(Err.Description, "Duplicate entry") > 0 Then
        If InStr(Err.Description, "for key 'operaciones.manifiesto") > 0 Then
            Me.txtManifiesto.SetFocus
            MsgBox "Este número de Manifiesto ya ha sido usado y no se admiten Manifiestos Repetidos.", vbExclamation, "Manifiesto Duplicado"
        ElseIf InStr(Err.Description, "for key 'operaciones.remesa") > 0 Then
            Me.txtRemesa.SetFocus
            MsgBox "Este número de Remesa ya ha sido usado y no se admiten Remesas Repetidas.", vbExclamation, "Remesa Duplicada"
        Else
            MsgBox "Error: " & Err.Number & " - " & Err.Description, vbCritical
        End If
    Else
        MsgBox "Error: " & Err.Number & " - " & Err.Description, vbCritical
    End If
End Sub

' Check box para deshabilitar Aux 1
Private Sub chkSinAux1_Click()
    ' Si el checkbox se acaba de marcar (lo que deshabilita el combo)...
    If Me.chkSinAux1.Value = True Then
        ' ...limpiamos los datos del combo y del cuadro de texto correspondiente.
        Me.cmbCcauxiliar1.Value = Null
        Me.txtNombreAuxiliar1.Value = Null
    End If
    
    ' Se llama a la subrutina central para que actualice el estado Enabled
    ' de los combos, lo cual es correcto y debe mantenerse.
    Call ActualizarLogicaCompletaAuxiliares
End Sub

' Check box para deshabilitar Aux 2
Private Sub chkSinAux2_Click()
    ' Si el checkbox se acaba de marcar (lo que deshabilita el combo)...
    If Me.chkSinAux2.Value = True Then
        ' ...limpiamos los datos del combo y del cuadro de texto correspondiente.
        Me.cmbCcauxiliar2.Value = Null
        Me.txtNombreAuxiliar2.Value = Null
    End If
    
    ' Lógica existente que debe mantenerse: Si se desmarca Aux 2,
    ' se deshabilita y desmarca también Aux 1 para mantener la jerarquía.
    If Me.chkSinAux2.Value = False Then
        Me.chkSinAux1.Enabled = False
        Me.chkSinAux1.Value = False
    Else
        Me.chkSinAux1.Enabled = True
    End If
    ' Se llama a la subrutina central para que actualice el estado Enabled
    ' de los combos, lo cual es correcto y debe mantenerse.
    Call ActualizarLogicaCompletaAuxiliares
End Sub

' Coloca el nombre del conductor en el campo nombre del conductor por id seleccionado en CC Conductor
Private Sub cmbConductor_AfterUpdate()
    ' Columna 1 = nombre (índice 1 porque empieza en 0)
    Me.txtNombreConductor = Me.cmbConductor.Column(1)
End Sub

Private Sub cmbEstacion_AfterUpdate()
    Dim sqlSectores As String
    Dim sqlAuxiliares As String
    Dim sqlCiudades As String
    Dim idEstacion As Long
    Dim nombreBase As String
    Dim idCiudadReferencia As Variant

    ' Limpiar los combos dependientes antes de recalcular
    Me.cmbSector.RowSource = ""
    Me.cmbSector.Value = Null
    Me.cmbCcauxiliar1.RowSource = ""
    Me.cmbCcauxiliar1.Value = Null
    Me.cmbCcauxiliar2.RowSource = ""
    Me.cmbCcauxiliar2.Value = Null
    Me.cmbCiudadPoblacion.RowSource = ""
    Me.cmbCiudadPoblacion.Value = Null
    
    Call ActualizarLogicaCompletaAuxiliares
    
    ' Verificar si se ha seleccionado una estación
    If IsNull(Me.cmbEstacion.Value) Then
        Me.cmbSector.Enabled = False
        Me.cmbCiudadPoblacion.Enabled = False
        Exit Sub
    Else
        ' Obtenemos los valores necesarios del ComboBox cmbEstacion
        idEstacion = Me.cmbEstacion.Value
        nombreBase = Me.cmbEstacion.Column(1)
        
        Me.cmbSector.Enabled = True
        Me.cmbCiudadPoblacion.Enabled = True
    End If
    
    ' --- 1. Construir SQL para SECTORES ---
    sqlSectores = "SELECT sector_id, sector, contrato FROM vista_sectores_deprisa " & _
                  "WHERE base_id = " & idEstacion & " ORDER BY sector;"
    Me.cmbSector.RowSource = sqlSectores
    
    ' --- 2. Construir SQL para AUXILIARES ---
    sqlAuxiliares = "SELECT identificacion, nombre FROM vista_auxiliares_transporte_activo " & _
                    "WHERE base_deprisa = '" & Replace(nombreBase, "'", "''") & "' ORDER BY nombre;"
    Me.cmbCcauxiliar1.RowSource = sqlAuxiliares
    Me.cmbCcauxiliar2.RowSource = sqlAuxiliares

    ' --- 3. CONSTRUIR SQL PARA CIUDADES (CONCATENANDO CIUDAD Y DEPARTAMENTO) ---
    sqlCiudades = "SELECT id_ciudad, ciudad & ' (' & Departamento_Estado & ')' AS CiudadCompleta " & _
                  "FROM vista_ciudades_departamentos " & _
                  "WHERE Pais = 'Colombia' " & _
                  "ORDER BY ciudad, Departamento_Estado;"
    
    Me.cmbCiudadPoblacion.RowSource = sqlCiudades
    
End Sub

Private Sub cmbHoraInicio_AfterUpdate()
    Dim horaSeleccionada As String
    Dim espacio As String
    
    horaSeleccionada = Nz(Me.cmbHoraInicio.Value, "")
    
    If horaSeleccionada = "" Then
        Exit Sub
    End If
    espacio = ChrW(8239)
    If InStr(horaSeleccionada, "p." & espacio & "m.") > 0 Then
        Dim respuesta As VbMsgBoxResult
        respuesta = MsgBox("Está seleccionando una hora de la tarde (p. m.). ¿Está seguro de que desea continuar?", vbExclamation + vbOKCancel, "Advertencia")
        
        If respuesta = vbCancel Then
            Me.cmbHoraInicio.Value = ""
            Me.txtNombreRuta.SetFocus
            Me.cmbHoraInicio.SetFocus
            DoEvents
            Exit Sub
        End If
    End If
    
End Sub

Private Sub cmbSector_AfterUpdate()
    Dim strContrato As String
    Dim strVehiculo As String
    On Error GoTo ManejarError
    If Me.cmbSector.ListIndex = -1 Then
        MsgBox "Debe seleccionar un sector válido de la lista.", vbExclamation
        Me.cmbSector = Null
        Me.txtVehiculo = ""
        Exit Sub
    End If
    
    Call VerificarYAsignarEstacion
    strContrato = Nz(Me.cmbSector.Column(2), "")
    If InStr(strContrato, " CM ") > 0 Then
        strVehiculo = "CAMION"
    ElseIf InStr(strContrato, " VN ") > 0 Then
        strVehiculo = "VAN"
    ElseIf InStr(strContrato, " MT ") > 0 Then
        strVehiculo = "MOTO"
    Else
        strVehiculo = ""
    End If
    Me.txtVehiculo = strVehiculo
    Call ActualizarEstadoMoto ' <-- AJUSTE: Llamar a la nueva lógica aquí
    Exit Sub
ManejarError:
    MsgBox "Error al procesar el sector seleccionado. Asegúrese de elegir un valor válido de la lista.", vbExclamation
    Me.cmbSector = Null
    Me.cmbSector.SetFocus
    Me.txtVehiculo = ""
    
End Sub

Private Sub cmbServicio_AfterUpdate()
    Me.cmbDriver.Requery
    Call VerificarYAsignarEstacion
    
End Sub

Private Sub Form_Load()
    Dim i As Integer
    Dim hora As Date
    Dim rsSesion As DAO.Recordset
    Dim valorBase As Variant
    
    'Borrar el formulario
    LimpiarAperturaOperacion Me
    Me.chkSinAux1 = False
    Me.chkSinAux2 = False
    ' Inicializar cmbEstacion con la base de la sesión actual
    Set rsSesion = CurrentDb.OpenRecordset("SELECT base_actual FROM tbl_sesion_actual", dbOpenSnapshot)
    If Not rsSesion.EOF Then
        valorBase = rsSesion!base_actual
        If Not IsNull(valorBase) And valorBase <> "" Then
            Me.cmbEstacion.Value = valorBase
            ' <<< LLAMA EL EVENTO QUE ACTUALIZA SECTORES Y AUXILIARES >>>
            Call cmbEstacion_AfterUpdate
        End If
    End If
    rsSesion.Close
    Call ActualizarLogicaCompletaAuxiliares
    Me.cmbHoraInicio.RowSourceType = "Value List"
    Me.cmbHoraInicio.RowSource = ""
    For i = 0 To 1439
        hora = TimeSerial(0, i, 0)
        Me.cmbHoraInicio.AddItem Format(hora, "hh:nn AM/PM")
    Next i
    Call ActualizarEstadoCamposPago
    If Not Me.chkSinAux2.Value Then
        Me.chkSinAux1.Enabled = False
    Else
        Me.chkSinAux1.Enabled = True
    End If
    If IsNull(Me.cmbEstacion) Or Me.cmbEstacion = "" Then
        Me.cmbSector.Enabled = False
    End If

    Call ActualizarEstadoMoto ' <-- AJUSTE: Asegura el estado correcto al cargar
End Sub

Private Sub cmbTipoPago_AfterUpdate()
    Call ActualizarEstadoCamposPago
End Sub

Private Sub ActualizarEstadoCamposPago()
    Dim tipoPago As String
    tipoPago = Nz(Me.cmbTipoPago, "")
    If tipoPago = "CAJA MENOR" Or tipoPago = "TRANS PRONTO PAGO" Then
        Me.txtConsecutivo.Enabled = True
        Me.txtValor.Enabled = True
    Else
        Me.txtConsecutivo.Enabled = False
        Me.txtValor.Enabled = False
    End If
    
End Sub

Private Function ValidarCamposObligatorios() As Boolean
    ValidarCamposObligatorios = False
    
    If IsNull(Me.txtFecha) Or Me.txtFecha = "" Then
        MsgBox "Debe ingresar la Fecha.", vbExclamation
        Me.txtFecha.SetFocus
        Exit Function
    End If
    If IsNull(Me.cmbEstacion) Or Me.cmbEstacion = "" Then
        MsgBox "Debe seleccionar la Estación.", vbExclamation
        Me.cmbEstacion.SetFocus
        Exit Function
    End If
    If IsNull(Me.cmbSector) Or Me.cmbSector = "" Then
        MsgBox "Debe seleccionar el Sector.", vbExclamation
        Me.cmbSector.SetFocus
        Exit Function
    End If
    ' <<< INICIO: AJUSTE - NUEVA VALIDACIÓN >>>
    If IsNull(Me.cmbCiudadPoblacion) Or Me.cmbCiudadPoblacion = "" Then
        MsgBox "Debe seleccionar la Ciudad / Población.", vbExclamation
        Me.cmbCiudadPoblacion.SetFocus
        Exit Function
    End If
    ' <<< FIN: AJUSTE >>>
    If IsNull(Me.cmbServicio) Or Me.cmbServicio = "" Then
        MsgBox "Debe seleccionar el Servicio.", vbExclamation
        Me.cmbServicio.SetFocus
        Exit Function
    End If
    If IsNull(Me.cmbDriver) Or Me.cmbDriver = "" Then
        MsgBox "Debe seleccionar el Driver.", vbExclamation
        Me.cmbDriver.SetFocus
        Exit Function
    End If
    If IsNull(Me.txtVehiculo) Or Me.txtVehiculo = "" Then
        MsgBox "Debe ingresar el tipo de Vehículo.", vbExclamation
        Me.txtVehiculo.SetFocus
        Exit Function
    End If
    If IsNull(Me.cmbPlaca) Or Me.cmbPlaca = "" Then
        MsgBox "Debe ingresar la Placa.", vbExclamation
        Me.cmbPlaca.SetFocus
        Exit Function
    End If
    If IsNull(Me.cmbTonelaje) Or Me.cmbTonelaje = "" Then
        MsgBox "Debe seleccionar el Tonelaje.", vbExclamation
        Me.cmbTonelaje.SetFocus
        Exit Function
    End If
    If IsNull(Me.cmbProveedor) Or Me.cmbProveedor = "" Then
        MsgBox "Debe seleccionar el Proveedor.", vbExclamation
        Me.cmbProveedor.SetFocus
        Exit Function
    End If
    If IsNull(Me.cmbTipoPago) Or Me.cmbTipoPago = "" Then
        MsgBox "Debe seleccionar el Tipo de Pago.", vbExclamation
        Me.cmbTipoPago.SetFocus
        Exit Function
    End If
    If IsNull(Me.txtNombreRuta) Or Me.txtNombreRuta = "" Then
        MsgBox "Debe ingresar el Nombre de la Ruta.", vbExclamation
        Me.txtNombreRuta.SetFocus
        Exit Function
    End If
    If IsNull(Me.cmbHoraInicio) Or Me.cmbHoraInicio = "" Then
        MsgBox "Debe seleccionar la Hora de Inicio.", vbExclamation
        Me.cmbHoraInicio.SetFocus
        Exit Function
    End If
    If IsNull(Me.txtEnvios) Or Me.txtEnvios = "" Then
        MsgBox "Debe ingresar el número de Envios.", vbExclamation
        Me.txtEnvios.SetFocus
        Exit Function
    End If
    If IsNull(Me.txtKmInicial) Or Me.txtKmInicial = "" Then
        MsgBox "Debe ingresar el Kilometraje Inicial.", vbExclamation
        Me.txtKmInicial.SetFocus
        Exit Function
    End If
    
    If Me.txtVehiculo.Value <> "MOTO" Then
        If IsNull(Me.txtRemesa) Or Me.txtRemesa = "" Then
            MsgBox "Debe ingresar la Remesa.", vbExclamation
            Me.txtRemesa.SetFocus
            Exit Function
        End If
        If IsNull(Me.txtManifiesto) Or Me.txtManifiesto = "" Then
            MsgBox "Debe ingresar el Manifiesto.", vbExclamation
            Me.txtManifiesto.SetFocus
            Exit Function
        End If
    End If
    
    If IsNull(Me.cmbClasUsoPxH) Or Me.cmbClasUsoPxH = "" Then
        MsgBox "Debe seleccionar la Clasificación de Uso PxH.", vbExclamation
        Me.cmbClasUsoPxH.SetFocus
        Exit Function
    End If
    If IsNull(Me.cmbConductor) Or Me.cmbConductor = "" Then
        MsgBox "Debe ingresar la Cédula del Conductor.", vbExclamation
        Me.cmbConductor.SetFocus
        Exit Function
    End If
    
    On Error Resume Next
    If Me!sub_tbl_ot_temporal.Form.RecordsetClone.RecordCount <= 0 Then
        MsgBox "Debe ingresar al menos un número de Orden de Trabajo (OT) para continuar.", vbExclamation
        Me!sub_tbl_ot_temporal.SetFocus
        On Error GoTo 0
        Exit Function
    End If
    On Error GoTo 0
        
    If Me.txtConsecutivo.Enabled Then
        If IsNull(Me.txtConsecutivo) Or Me.txtConsecutivo = "" Then
            MsgBox "Debe ingresar el Consecutivo para Caja Menor.", vbExclamation
            Me.txtConsecutivo.SetFocus
            Exit Function
        End If
    End If
    If Me.txtValor.Enabled Then
        If IsNull(Me.txtValor) Or Me.txtValor = "" Then
            MsgBox "Debe ingresar el Valor para Caja Menor.", vbExclamation
            Me.txtValor.SetFocus
            Exit Function
        End If
    End If
    If Me.cmbCcauxiliar1.Enabled Then
        If IsNull(Me.cmbCcauxiliar1) Or Me.cmbCcauxiliar1 = "" Then
            MsgBox "Debe ingresar el número de identificación del Auxiliar 1.", vbExclamation
            Me.cmbCcauxiliar1.SetFocus
            Exit Function
        End If
    End If
    If Me.cmbCcauxiliar2.Enabled Then
        If IsNull(Me.cmbCcauxiliar2) Or Me.cmbCcauxiliar2 = "" Then
            MsgBox "Debe ingresar el número de identificación del Auxiliar 2.", vbExclamation
            Me.cmbCcauxiliar2.SetFocus
            Exit Function
        End If
    End If
    ValidarCamposObligatorios = True
    
End Function

' Logica de manejo del control de id auxiliar 1
Private Sub cmbCcauxiliar1_AfterUpdate()
    ' Validar que el Auxiliar 1 no sea igual a Auxiliar 2
    If Not IsNull(Me.cmbCcauxiliar1) And Not IsNull(Me.cmbCcauxiliar2) Then
        If Me.cmbCcauxiliar1.Value = Me.cmbCcauxiliar2.Value Then
            MsgBox "No puede seleccionar el mismo Auxiliar en ambos campos.", vbExclamation
            Me.cmbCcauxiliar1.Value = Null
            Me.txtNombreAuxiliar1.Value = Null
            Exit Sub
        End If
    End If
    ' Revisa si el combo de Auxiliar 1 está vacío.
    If IsNull(Me.cmbCcauxiliar1) Or Me.cmbCcauxiliar1 = "" Then
        ' 1. Limpia el cuadro de texto del nombre del Auxiliar 1.
        Me.txtNombreAuxiliar1.Value = Null
        ' 2. Lógica existente: Limpia el combo del Auxiliar 2.
        Me.cmbCcauxiliar2.Value = Null
        ' 3. Adición: Limpia también el cuadro de texto del nombre del Auxiliar 2.
        Me.txtNombreAuxiliar2.Value = Null
    Else
        ' Si se seleccionó un valor:
        ' Muestra el nombre (que está en la 2da columna, índice 1) en el cuadro de texto.
        Me.txtNombreAuxiliar1.Value = Me.cmbCcauxiliar1.Column(1)
    End If
End Sub

' Logica de manejo del control de id auxiliar 2
Private Sub cmbCcauxiliar2_AfterUpdate()
    ' Validar que el Auxiliar 2 no sea igual a Auxiliar 1
    If Not IsNull(Me.cmbCcauxiliar2) And Not IsNull(Me.cmbCcauxiliar1) Then
        If Me.cmbCcauxiliar2.Value = Me.cmbCcauxiliar1.Value Then
            MsgBox "No puede seleccionar el mismo Auxiliar en ambos campos.", vbExclamation
            Me.cmbCcauxiliar2.Value = Null
            Me.txtNombreAuxiliar2.Value = Null
            Exit Sub
        End If
    End If
    ' Lógica existente: Si se intenta llenar Aux 2 mientras Aux 1 está vacío...
    If IsNull(Me.cmbCcauxiliar1) Or Me.cmbCcauxiliar1 = "" Then
        ' ...pero solo si el usuario realmente seleccionó un valor (y no lo borró).
        If Not IsNull(Me.cmbCcauxiliar2.Value) Then
            MsgBox "Debe ingresar primero el ID del Auxiliar 1 antes de llenar el ID del Auxiliar 2.", vbExclamation
            Me.cmbCcauxiliar2.Value = Null ' Limpia el valor inválido
            Me.cmbCcauxiliar1.SetFocus   ' Mueve el foco al lugar correcto
            Exit Sub ' Detiene la ejecución para no continuar.
        End If
    End If
    ' Nueva lógica: Si la validación pasó o no fue necesaria...
    If Not IsNull(Me.cmbCcauxiliar2.Value) Then
        ' Si se seleccionó un valor, muestra el nombre.
        Me.txtNombreAuxiliar2.Value = Me.cmbCcauxiliar2.Column(1)
    Else
        ' Si el valor fue borrado, limpia el nombre.
        Me.txtNombreAuxiliar2.Value = Null
    End If
End Sub

Private Sub chkSinAux1_AfterUpdate()
    If Me.chkSinAux1.Value = True And Me.chkSinAux2.Value = False Then
        MsgBox "Primero debe deshabilitar el Auxiliar 2 antes de deshabilitar el Auxiliar 1.", vbExclamation
        Me.chkSinAux1 = False
    End If
    
    ' --- AJUSTE: Se llama a la subrutina central para recalcular el estado Enabled ---
    Call ActualizarEstadoAuxiliares
    
End Sub

Private Sub txtNombreRuta_AfterUpdate()
    Me.txtNombreRuta = UCase(Me.txtNombreRuta)
    
End Sub

Private Sub cmbPlaca_AfterUpdate()
    ' Primero, verificar si se ha seleccionado o ingresado un valor en el combobox
    If Not IsNull(Me.cmbPlaca.Value) Then
        
        ' --- LÓGICA EXISTENTE (Preservada) ---
        ' Se asegura de que la placa esté en mayúsculas.
        Me.cmbPlaca.Value = UCase(Me.cmbPlaca.Value)
        
        ' --- NUEVA LÓGICA  ---
        ' Ahora que la placa está limpia y en mayúsculas, buscar su proveedor
        ' en la vista consolidada.
        Me.cmbProveedor.Value = DLookup("tipo_proveedor", "vista_consolidado_vehiculos", "placa = '" & Me.cmbPlaca.Value & "'")
        
    Else
        
        ' --- NUEVA LÓGICA (para el caso de borrado) ---
        ' Si el usuario borra el contenido de cmbPlaca, también se borra el proveedor.
        Me.cmbProveedor.Value = Null
        
    End If
End Sub

Private Sub txtRemesa_AfterUpdate()
    If Not IsNull(Me.txtRemesa) Then
        Me.txtRemesa = UCase(Me.txtRemesa)
    End If
    
End Sub

Private Sub txtManifiesto_AfterUpdate()
    If Not IsNull(Me.txtManifiesto) Then
        Me.txtManifiesto = UCase(Me.txtManifiesto)
    End If
    
End Sub

Private Sub cmbDriver_AfterUpdate()
    Call VerificarYAsignarEstacion
    
End Sub

Private Sub VerificarYAsignarEstacion()
    Dim sectorTexto As String
    Dim servicioTexto As String
    Dim driverTexto As String
    Dim estacionTexto As String
    Dim horaActual As String
    sectorTexto = Nz(Me.cmbSector.Column(1), "")
    servicioTexto = Nz(Me.cmbServicio.Column(1), "")
    driverTexto = Nz(Me.cmbDriver.Column(1), "")
    If InStr(1, sectorTexto, "ESTACION", vbTextCompare) > 0 And _
       servicioTexto = "BackOffice" And _
       driverTexto = "Horas Extra / Recargos de Personal" Then
        Me.txtVehiculo = "CAMION"
        Me.cmbPlaca = "ESTACION"
        estacionTexto = Nz(Me.cmbEstacion.Column(1), "")
        horaActual = Format(Now, "hh:nn:ss")
        
        Me.txtRemesa = estacionTexto & horaActual
        Me.txtManifiesto = horaActual & estacionTexto
        
        Me.cmbTonelaje.SetFocus
    End If
    
    Call ActualizarEstadoMoto ' <-- AJUSTE: Llamar a la lógica por si cambia el vehículo
End Sub

' --- INICIO: NUEVA SUBRUTINA DE EVENTO ---
' Evento para el campo de texto del vehículo
Private Sub txtVehiculo_AfterUpdate()
    Call ActualizarEstadoMoto
End Sub
' --- FIN: NUEVA SUBRUTINA DE EVENTO ---



