VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Back_Office"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database


Private Sub BTN_Borrar_Click()

    ' Vuelve a cargar sectores/auxiliares dependientes de estación fija
    Call cmbEstacion_AfterUpdate
End Sub

Private Sub btnBorrarBOCierre_Click()
    LimpiarControlesCierreBackOffice
End Sub

Private Sub btnLimpiarOtros_Click()
    Call LimpiarCampos
End Sub

' Correr consulta en listBackOffice cuando se actualice la fecha
Private Sub txtFecha_AfterUpdate()
    Me.listBackOffice.Requery
End Sub


' Acciones a ejcutar boton guardar
Private Sub BTN_Guardar_Click()
    On Error GoTo ErrHandler
    
    Dim cmd As ADODB.Command
    Dim usuarioActual As String
    
    ' 1. Validar campos obligatorios básicos
    If IsNull(Me.txtFecha) Or Me.txtFecha = "" Then
        MsgBox "Debe ingresar la Fecha.", vbExclamation
        Me.txtFecha.SetFocus: Exit Sub
    End If
    If IsNull(Me.cmbEstacion) Or Me.cmbEstacion = "" Then
        MsgBox "Debe seleccionar la Estación.", vbExclamation
        Me.cmbEstacion.SetFocus: Exit Sub
    End If
    If IsNull(Me.cmbServicio) Or Me.cmbServicio = "" Then
        MsgBox "Debe seleccionar el Servicio.", vbExclamation
        Me.cmbServicio.SetFocus: Exit Sub
    End If
    If IsNull(Me.cmbDriver) Or Me.cmbDriver = "" Then
        MsgBox "Debe seleccionar el Driver.", vbExclamation
        Me.cmbDriver.SetFocus: Exit Sub
    End If
    If IsNull(Me.cmbTipoPago) Or Me.cmbTipoPago = "" Then
        MsgBox "Debe seleccionar el Tipo de Pago.", vbExclamation
        Me.cmbTipoPago.SetFocus: Exit Sub
    End If
    If IsNull(Me.cmbProveedor) Or Me.cmbProveedor = "" Then
        MsgBox "Debe seleccionar el Proveedor.", vbExclamation
        Me.cmbProveedor.SetFocus: Exit Sub
    End If
    If IsNull(Me.cmbHoraInicio) Or Me.cmbHoraInicio = "" Then
        MsgBox "Debe seleccionar la Hora de Inicio.", vbExclamation
        Me.cmbHoraInicio.SetFocus: Exit Sub
    End If
    If IsNull(Me.cmbCcauxiliar1) Or Me.cmbCcauxiliar1 = "" Then
        MsgBox "Debe seleccionar el Auxiliar 1.", vbExclamation
        Me.cmbCcauxiliar1.SetFocus: Exit Sub
    End If
    
    ' 2. Validar Caja Menor si corresponde
    Dim consecutivoVal As Variant
    Dim valorVal As Variant
    
    If Me.txtConsecutivo.Enabled Then
        If IsNull(Me.txtConsecutivo) Or Me.txtConsecutivo = "" Then
            MsgBox "Debe ingresar el Consecutivo para Caja Menor.", vbExclamation
            Me.txtConsecutivo.SetFocus: Exit Sub
        End If
        consecutivoVal = Me.txtConsecutivo.Value
    Else
        consecutivoVal = Null
    End If
    
    If Me.txtValor.Enabled Then
        If IsNull(Me.txtValor) Or Me.txtValor = "" Then
            MsgBox "Debe ingresar el Valor para Caja Menor.", vbExclamation
            Me.txtValor.SetFocus: Exit Sub
        End If
        valorVal = Me.txtValor.Value
    Else
        valorVal = Null
    End If

    ' 3. Verificar y reconectar a MySQL si es necesario
    If Not VerificarYReconectarMySQL() Then
        MsgBox "No se pudo establecer conexión con MySQL. Intente nuevamente.", vbCritical
        Exit Sub
    End If
    
    ' 4. Obtener el usuario actual
    usuarioActual = EstablecerUsuarioActual()
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual. Intente nuevamente.", vbCritical
        Exit Sub
    End If
    
    ' 5. Ejecutar el SP de apertura BackOffice con caja menor opcional
    Set cmd = New ADODB.Command
    With cmd
        .ActiveConnection = cnn
        .CommandType = adCmdStoredProc
        .CommandText = "Insertar_BackOffice_Apertura"
        
        .Parameters.Append .CreateParameter("p_fecha", adDate, adParamInput, , Me.txtFecha.Value)
        .Parameters.Append .CreateParameter("p_estacion", adInteger, adParamInput, , Me.cmbEstacion.Value)
        .Parameters.Append .CreateParameter("p_servicio", adInteger, adParamInput, , Me.cmbServicio.Value)
        .Parameters.Append .CreateParameter("p_driver", adInteger, adParamInput, , Me.cmbDriver.Value)
        .Parameters.Append .CreateParameter("p_tipo_pago", adVarChar, adParamInput, 20, Me.cmbTipoPago.Value)
        .Parameters.Append .CreateParameter("p_proveedor", adVarChar, adParamInput, 3, Me.cmbProveedor.Value)
        .Parameters.Append .CreateParameter("p_backof_1", adVarChar, adParamInput, 20, Me.cmbCcauxiliar1.Value)
        .Parameters.Append .CreateParameter("p_hora_inicial", adDBTime, adParamInput, , Me.cmbHoraInicio.Value)
        .Parameters.Append .CreateParameter("p_consecutivo", adVarChar, adParamInput, 200, consecutivoVal)
        Dim prmValor As ADODB.Parameter
        Set prmValor = .CreateParameter("p_valor", adNumeric, adParamInput, 10, valorVal)
        prmValor.Precision = 10
        prmValor.NumericScale = 2
        .Parameters.Append prmValor
        .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)
        
        .Execute
    End With
    
    Set cmd = Nothing
    
    MsgBox "Registro BackOffice guardado exitosamente.", vbInformation
    Call LimpiarControlesApertura
    Call LimpiarControlesCierreBackOffice
    
    Exit Sub

ErrHandler:
    If InStr(Err.Description, "Duplicate entry") > 0 Then
        MsgBox "Ya existe un registro con estos datos. Verifique la información.", vbExclamation
    Else
        MsgBox "Error al guardar: " & Err.Number & " - " & Err.Description, vbCritical
    End If
    If Not cmd Is Nothing Then Set cmd = Nothing
End Sub

Private Sub cmbEstacion_AfterUpdate()
    Me.cmbCcauxiliar1.RowSource = ""
    Me.cmbCcauxiliar1.Value = Null
    Call ActualizarEstadoAuxiliar1
    Call ActualizarRowSourceAuxiliar1
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
            Me.cmbHoraInicio.SetFocus
            DoEvents
            Exit Sub
        End If
    End If
    
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

    ' Inicializar cmbEstacion con la base de la sesión actual
    Set rsSesion = CurrentDb.OpenRecordset("SELECT base_actual FROM tbl_sesion_actual", dbOpenSnapshot)
    If Not rsSesion.EOF Then
        valorBase = rsSesion!base_actual
        If Not IsNull(valorBase) And valorBase <> "" Then
            ' Asignar el valor (base_id) y luego forzar recarga y evento
            Me.cmbEstacion = valorBase
            Me.cmbEstacion.Requery
            Me.cmbEstacion.Value = valorBase ' doble asignación asegura selección incluso si el combo recarga tras el set
            Call cmbEstacion_AfterUpdate
        End If
    End If

    rsSesion.Close

    ' inicialización cmbHoraInicio para cargar horas en formato 12 h
    Me.cmbHoraInicio.RowSourceType = "Value List"
    Me.cmbHoraInicio.RowSource = ""

    For i = 0 To 1439
        hora_in = TimeSerial(0, i, 0)
        Me.cmbHoraInicio.AddItem Format(hora_in, "hh:nn AM/PM")
    Next i

    ' inicialización cmbHoraFinal para cargar horas en formato 12 h
    Me.cmbHorafinal.RowSourceType = "Value List"
    Me.cmbHorafinal.RowSource = ""

    For y = 0 To 1439
        hora_fin = TimeSerial(0, y, 0)
        Me.cmbHorafinal.AddItem Format(hora_fin, "hh:nn AM/PM")
    Next y
    
    ' Ocultar controles de opcion 3 (Otros)
    Me.txtObservaciones.Visible = False
    Me.btnLimpiarOtros.Visible = False
    Me.btnGuardarOtros.Visible = False
    
    ' deshabilitar controles
    Me.cmbHorafinal.Enabled = False
    Me.txtBackOffice_id.Enabled = False
    Me.btnBorrarBOCierre.Enabled = False
    Me.btnGuardarBOCierre.Enabled = False

    ' Al final, llama la rutina del grupo de opciones para asegurar el estado correcto
    Call Marco94_AfterUpdate
End Sub


   

' Logica de manejo del control de id auxiliar 1
Private Sub cmbCcauxiliar1_AfterUpdate()

    ' Revisa si el combo de Auxiliar 1 está vacío.
    If IsNull(Me.cmbCcauxiliar1) Or Me.cmbCcauxiliar1 = "" Then
        ' 1. Limpia el cuadro de texto del nombre del Auxiliar 1.
        Me.txtNombreAuxiliar1.Value = Null

    Else
        ' Si se seleccionó un valor:
        ' Muestra el nombre (que está en la 2da columna, índice 1) en el cuadro de texto.
        Me.txtNombreAuxiliar1.Value = Me.cmbCcauxiliar1.Column(1)
    End If
End Sub

Private Sub cmbDriver_AfterUpdate()
    
    ' Chequeo dinámico mientras el usuario cambia de driver y Marco94=3
    Call ActualizarAuxiliar1SegunMarcoYDriver
    
    Call ActualizarEstadoAuxiliar1
    
    Call ActualizarRowSourceAuxiliar1
    
    Call VerificarYAsignarEstacion
         
End Sub

Private Sub VerificarYAsignarEstacion()
    Dim sectorTexto As String
    Dim servicioTexto As String
    Dim driverTexto As String
    Dim estacionTexto As String
    Dim horaActual As String

    servicioTexto = Nz(Me.cmbServicio.Column(1), "")
    driverTexto = Nz(Me.cmbDriver.Column(1), "")

    If InStr(1, sectorTexto, "ESTACION", vbTextCompare) > 0 And _
       servicioTexto = "BackOffice" And _
       driverTexto = "Horas Extra / Recargos de Personal" Then

 
        estacionTexto = Nz(Me.cmbEstacion.Column(1), "")
        horaActual = Format(Now, "hh:nn:ss")
    
        
    End If
    
End Sub

Private Sub Marco94_AfterUpdate()
    Select Case Me.Marco94
        Case 1 ' Iniciar registro BackOffice
            Me.cmbServicio.RowSource = "SELECT servicio_id, nombre FROM vista_servicio WHERE servicio_id = 3 ORDER BY nombre;"
            Me.cmbServicio.Value = 3
            Me.cmbServicio.Enabled = True
            Me.cmbDriver.Enabled = True
            Me.cmbTipoPago.Enabled = True
            Me.cmbProveedor.Enabled = True
            Me.cmbHoraInicio.Enabled = True
            Me.cmbCcauxiliar1.Enabled = True
            Me.txtNombreAuxiliar1.Enabled = True
            Me.cmbCcauxiliar1.Value = Null
            Me.txtNombreAuxiliar1.Value = ""
            Me.BTN_Borrar.Enabled = True
            Me.BTN_Guardar.Enabled = True

            Me.listBackOffice.Enabled = False
            Me.cmbHorafinal.Value = Null
            Me.cmbHorafinal.Enabled = False
            Me.txtBackOffice_id.Value = ""
            Me.txtBackOffice_id.Enabled = False
            Me.btnBorrarBOCierre.Enabled = False
            Me.btnGuardarBOCierre.Enabled = False

            ' Estos siempre visibles en opción 1
            Me.listBackOffice.Visible = True
            Me.cmbHorafinal.Visible = True
            Me.txtBackOffice_id.Visible = True
            Me.btnBorrarBOCierre.Visible = True
            Me.btnGuardarBOCierre.Visible = True
            
            ' Ocultar Controls de Opción 3
            Me.txtObservaciones.Visible = False
            Me.btnLimpiarOtros.Visible = False
            Me.btnGuardarOtros.Visible = False

        Case 2 ' Cierre registro BackOffice
            Me.cmbServicio.RowSource = "SELECT servicio_id, nombre FROM vista_servicio WHERE servicio_id IN (3,4) ORDER BY nombre;"
            Me.cmbServicio.Value = Null
            Me.cmbServicio.Enabled = False
            Me.cmbDriver.Enabled = False
            Me.cmbTipoPago.Enabled = False
            Me.cmbProveedor.Value = Null
            Me.cmbProveedor.Enabled = False
            Me.cmbHoraInicio.Enabled = False
            Me.cmbCcauxiliar1.Value = Null
            Me.txtNombreAuxiliar1.Value = ""
            Me.cmbCcauxiliar1.Enabled = False
            Me.txtNombreAuxiliar1.Enabled = False
            Me.BTN_Borrar.Enabled = False
            Me.BTN_Guardar.Enabled = False

            Me.listBackOffice.Enabled = True
            Me.cmbHorafinal.Value = Null
            Me.cmbHorafinal.Enabled = False
            Me.txtBackOffice_id.Value = ""
            Me.txtBackOffice_id.Enabled = False
            Me.btnBorrarBOCierre.Enabled = False
            Me.btnGuardarBOCierre.Enabled = False

            ' Siempre visibles en opción 2
            Me.listBackOffice.Visible = True
            Me.cmbHorafinal.Visible = True
            Me.txtBackOffice_id.Visible = True
            Me.btnBorrarBOCierre.Visible = True
            Me.btnGuardarBOCierre.Visible = True
            
            ' Ocultar Controls de Opción 3
            Me.txtObservaciones.Visible = False
            Me.btnLimpiarOtros.Visible = False
            Me.btnGuardarOtros.Visible = False

        Case 3 ' Solo mostrar servicio_id = 4 y ocultar controles de cierre
            Me.cmbServicio.RowSource = "SELECT servicio_id, nombre FROM vista_servicio WHERE servicio_id = 4 ORDER BY nombre;"
            Me.cmbServicio.Value = 4
            Me.cmbServicio.Enabled = True
            Me.cmbDriver.Enabled = True
            Me.cmbTipoPago.Enabled = True
            Me.cmbProveedor.Enabled = True
            Me.cmbProveedor.Value = Null
            Me.cmbHoraInicio.Enabled = False
            Me.cmbCcauxiliar1.Enabled = False
            Me.txtNombreAuxiliar1.Enabled = False
            Me.BTN_Borrar.Enabled = False
            Me.BTN_Guardar.Enabled = False

            Me.listBackOffice.Enabled = False
            Me.cmbHorafinal.Enabled = False
            Me.btnBorrarBOCierre.Enabled = False
            Me.btnGuardarBOCierre.Enabled = False

            ' OCULTA estos controles en opción 3
            Me.listBackOffice.Visible = False
            Me.cmbHorafinal.Value = Null
            Me.cmbHorafinal.Visible = False
            Me.txtBackOffice_id.Value = ""
            Me.txtBackOffice_id.Visible = False
            Me.btnBorrarBOCierre.Visible = False
            Me.btnGuardarBOCierre.Visible = False
            
            ' Muestra los controles de la opcion 3
            Me.txtObservaciones.Visible = True
            Me.btnLimpiarOtros.Visible = True
            Me.btnGuardarOtros.Visible = True
            
            ' Activa los controles para ingresar número de CC de personal cargue/descargue
            Call ActualizarAuxiliar1SegunMarcoYDriver


        Case Else
            Me.cmbServicio.RowSource = "SELECT servicio_id, nombre FROM vista_servicio WHERE servicio_id IN (3,4) ORDER BY nombre;"
            Me.cmbServicio.Value = Null
            Me.cmbServicio.Enabled = False
            Me.cmbDriver.Enabled = False
            Me.cmbTipoPago.Enabled = False
            Me.cmbProveedor.Enabled = False
            Me.cmbHoraInicio.Enabled = False
            Me.cmbCcauxiliar1.Enabled = False
            Me.txtNombreAuxiliar1.Enabled = False
            Me.BTN_Borrar.Enabled = False
            Me.BTN_Guardar.Enabled = False

            Me.listBackOffice.Enabled = False
            Me.cmbHorafinal.Enabled = False
            Me.btnBorrarBOCierre.Enabled = False
            Me.btnGuardarBOCierre.Enabled = False

            ' Por defecto, estos controles visibles
            Me.listBackOffice.Visible = True
            Me.cmbHorafinal.Visible = True
            Me.btnBorrarBOCierre.Visible = True
            Me.btnGuardarBOCierre.Visible = True
    End Select

    Me.cmbServicio.Requery
    Call cmbServicio_AfterUpdate
    Call ActualizarEstadoAuxiliar1
    Call ActualizarRowSourceAuxiliar1
End Sub

Private Sub cmbTipoPago_AfterUpdate()
    Dim tipoPago As String
    tipoPago = Nz(Me.cmbTipoPago.Value, "")

    If tipoPago = "CAJA MENOR" Or tipoPago = "TRANS PRONTO PAGO" Then
        Me.txtConsecutivo.Enabled = True
        Me.txtValor.Enabled = True
    Else
        Me.txtConsecutivo.Enabled = False
        Me.txtValor.Enabled = False
        Me.txtConsecutivo.Value = Null
        Me.txtValor.Value = Null
    End If
End Sub


Private Sub ActualizarAuxiliar1SegunMarcoYDriver()
    If Me.Marco94 = 3 And Nz(Me.cmbDriver.Value, 0) = 16 Then
        Me.cmbCcauxiliar1.Enabled = True
        Me.txtNombreAuxiliar1.Enabled = True
    Else
        Me.cmbCcauxiliar1.Enabled = False
        Me.txtNombreAuxiliar1.Enabled = False
        Me.cmbCcauxiliar1.Value = Null
        Me.txtNombreAuxiliar1.Value = ""
    End If
End Sub

' función para controlar el origen de fila del control cmbCcauxiliar1
Private Sub ActualizarRowSourceAuxiliar1()
    Dim sqlSource As String
    Dim baseFiltrar As String
    Dim driverID As Long

    baseFiltrar = Nz(Me.cmbEstacion.Column(1), "")
    driverID = Nz(Me.cmbDriver.Value, 0)

    ' Casos para Marco94 = 1
    If Me.Marco94 = 1 Then
        Select Case driverID
            Case 6, 7, 8, 9
                sqlSource = "SELECT identificacion, nombre FROM vista_auxiliares_transporte_activo WHERE base_deprisa = '" & Replace(baseFiltrar, "'", "''") & "' ORDER BY nombre;"

            Case 11, 12
                sqlSource = "SELECT identificacion, nombre FROM vista_supervisores_coodinadores_activo_operaciones WHERE base_deprisa = '" & Replace(baseFiltrar, "'", "''") & "' ORDER BY nombre;"

            Case 10
                sqlSource = _
                    "SELECT identificacion, nombre FROM vista_auxiliares_transporte_activo WHERE base_deprisa = '" & Replace(baseFiltrar, "'", "''") & "'" & _
                    " UNION ALL SELECT identificacion, nombre FROM vista_supervisores_coodinadores_activo_operaciones WHERE base_deprisa = '" & Replace(baseFiltrar, "'", "''") & "' ORDER BY nombre;"

            Case Else
                sqlSource = ""
        End Select

    ' Caso para Marco94 = 3 y Driver 16
    ElseIf Me.Marco94 = 3 And driverID = 16 Then
        sqlSource = "SELECT identificacion, nombre FROM vista_auxiliares_transporte_activo WHERE base_deprisa = '" & Replace(baseFiltrar, "'", "''") & "' ORDER BY nombre;"
    Else
        sqlSource = ""
    End If
    
    Me.cmbCcauxiliar1.RowSource = sqlSource
    Me.cmbCcauxiliar1.Value = Null
    Me.cmbCcauxiliar1.Requery
End Sub

Private Sub ActualizarEstadoAuxiliar1()
    Dim driverID As Long
    driverID = Nz(Me.cmbDriver.Value, 0)

    If Me.Marco94 = 1 And Not IsNull(Me.cmbEstacion.Value) Then
        Select Case driverID
            Case 6, 7, 8, 9, 10, 11, 12
                Me.cmbCcauxiliar1.Enabled = True
                Me.txtNombreAuxiliar1.Enabled = True
            Case Else
                Me.cmbCcauxiliar1.Enabled = False
                Me.txtNombreAuxiliar1.Enabled = False
        End Select
    ElseIf Me.Marco94 = 3 And driverID = 16 And Not IsNull(Me.cmbEstacion.Value) Then
        Me.cmbCcauxiliar1.Enabled = True
        Me.txtNombreAuxiliar1.Enabled = True
    Else
        Me.cmbCcauxiliar1.Enabled = False
        Me.txtNombreAuxiliar1.Enabled = False
    End If
End Sub

' Función para limpiar los campos de apertura registro backoffice
Private Sub LimpiarControlesApertura()
    ' Limpiar valores
    Me.cmbDriver.Value = Null
    Me.cmbTipoPago.Value = Null
    Me.cmbProveedor.Value = Null
    Me.cmbHoraInicio.Value = Null
    Me.cmbCcauxiliar1.Value = Null
    Me.txtNombreAuxiliar1.Value = Null
    Me.txtConsecutivo.Value = Null
    Me.txtValor.Value = Null

End Sub

Private Sub listBackOffice_AfterUpdate()
    ' Supón que la primera columna (columna 0) es backoffice_id (BO.backoffice_id)
    If Me.listBackOffice.ListIndex <> -1 Then
        Me.txtBackOffice_id.Value = Me.listBackOffice.Column(0)
        Me.cmbHorafinal.Enabled = True
        Me.txtBackOffice_id.Enabled = True
        Me.btnBorrarBOCierre.Enabled = True
        Me.btnGuardarBOCierre.Enabled = True
    Else
        Me.txtBackOffice_id.Value = Null
        Me.cmbHorafinal.Enabled = False
        Me.txtBackOffice_id.Enabled = False
        Me.btnBorrarBOCierre.Enabled = False
        Me.btnGuardarBOCierre.Enabled = False
    End If
End Sub

' evento de cierre registro backoffice
Private Sub btnGuardarBOCierre_Click()
    On Error GoTo ErrHandler

    Dim sql           As String
    Dim usuarioActual As String
    Dim backOfficeID  As Long
    Dim horaFinal     As Date
    Dim horaFinalStr  As String

    ' 1. Validar campos obligatorios
    If IsNull(Me.cmbHorafinal) Or Me.cmbHorafinal = "" Then
        MsgBox "Debe seleccionar la Hora Final.", vbExclamation
        Me.cmbHorafinal.SetFocus: Exit Sub
    End If
    If IsNull(Me.txtBackOffice_id) Or Me.txtBackOffice_id = "" Then
        MsgBox "Debe seleccionar un registro de BackOffice para cerrar.", vbExclamation
        Me.listBackOffice.SetFocus: Exit Sub
    End If

    ' 2. Conexión y usuario
    If Not VerificarYReconectarMySQL() Then
        MsgBox "No se pudo establecer conexión con MySQL.", vbCritical: Exit Sub
    End If
    usuarioActual = EstablecerUsuarioActual()
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual.", vbCritical: Exit Sub
    End If

    ' 3. Preparar valores
    backOfficeID = CLng(Me.txtBackOffice_id.Value)
    horaFinal = Me.cmbHorafinal.Value
    ' Formatear a cadena 24h
    horaFinalStr = Format(horaFinal, "HH:mm:ss")

    ' 4. Montar y ejecutar llamada SQL directamente
    sql = "CALL Actualizar_BackOffice_Cierre(" & _
          backOfficeID & ", '" & horaFinalStr & "', '" & usuarioActual & "');"

    cnn.Execute sql

    MsgBox "Cierre de BackOffice realizado exitosamente.", vbInformation
    Call LimpiarControlesCierreBackOffice
    Exit Sub

ErrHandler:
    MsgBox "Error al guardar cierre: " & Err.Number & " - " & Err.Description, vbCritical
End Sub

' funcion limpiar formulario cierre backoffice
Private Sub LimpiarControlesCierreBackOffice()
    ' Limpiar valores
    Me.cmbHorafinal.Value = Null
    Me.txtBackOffice_id.Value = Null

    ' Deshabilitar controles
    Me.cmbHorafinal.Enabled = False
    Me.txtBackOffice_id.Enabled = False
    Me.btnBorrarBOCierre.Enabled = False
    Me.btnGuardarBOCierre.Enabled = False

    ' Actualizar lista de registros
    Me.listBackOffice.Requery
End Sub

' Boton insertar registro para opción otros
Private Sub btnGuardarOtros_Click()
    Dim cmd As ADODB.Command
    Dim usuarioActual As String
    Dim sqlCall As String
    
    ' Validaciones
    If Me.cmbDriver = 16 Then
        If Nz(Me.cmbCcauxiliar1, "") = "" Then
            MsgBox "Debe seleccionar Cc Auxiliar 1 cuando el driver es 16.", vbExclamation
            Me.cmbCcauxiliar1.SetFocus: Exit Sub
        End If
        If Nz(Me.txtNombreAuxiliar1, "") = "" Then
            MsgBox "Debe ingresar Nombre Auxiliar 1 cuando el driver es 16.", vbExclamation
            Me.txtNombreAuxiliar1.SetFocus: Exit Sub
        End If
    End If
    If Nz(Me.txtObservaciones, "") = "" Then
        MsgBox "El campo Observaciones es obligatorio.", vbExclamation
        Me.txtObservaciones.SetFocus: Exit Sub
    End If
    If Me.txtConsecutivo.Enabled Then
        If Nz(Me.txtConsecutivo, "") = "" Then
            MsgBox "El campo Consecutivo es obligatorio.", vbExclamation
            Me.txtConsecutivo.SetFocus: Exit Sub
        End If
        If Nz(Me.txtValor, 0) = 0 Then
            MsgBox "El campo Valor es obligatorio y debe ser mayor que cero.", vbExclamation
            Me.txtValor.SetFocus: Exit Sub
        End If
    End If
    
    ' Asegurar y establecer usuario en variable de sesión MySQL
    If EstablecerUsuarioActual() = "" Then Exit Sub
    
    ' Construir llamada al SP en una sola línea
    sqlCall = "CALL Insertar_BackOffice_Con_Observacion('" & _
              Format(Me.txtFecha, "yyyy\-mm\-dd") & "'," & _
              Me.cmbEstacion & "," & Me.cmbServicio & "," & Me.cmbDriver & ",'" & _
              Me.cmbTipoPago & "','" & Me.cmbProveedor & "','" & Nz(Me.cmbCcauxiliar1, "") & "'," & _
              "NULL,NULL,'" & Replace(Me.txtObservaciones, "'", "''") & "'," & _
              IIf(Me.txtConsecutivo.Enabled, "'" & Nz(Me.txtConsecutivo, "") & "'", "NULL") & "," & _
              IIf(Me.txtConsecutivo.Enabled, Nz(Me.txtValor, 0), "NULL") & "," & _
              "'" & usuario & "'" & ");"
    
    On Error GoTo Err_Handler
    
    ' Verificar o reconectar ADO MySQL
    If Not VerificarYReconectarMySQL() Then Exit Sub
    
    ' Ejecutar el SP vía ADO
    Set cmd = New ADODB.Command
    With cmd
        .ActiveConnection = cnn
        .CommandText = sqlCall
        .CommandType = adCmdText
        .Execute
    End With
    
    MsgBox "Registro guardado correctamente.", vbInformation
    DoCmd.Requery
    Call LimpiarCampos

Exit_Sub:
    Set cmd = Nothing
    Exit Sub

Err_Handler:
    MsgBox "Error " & Err.Number & ": " & Err.Description, vbCritical, "Error al guardar"
    Resume Exit_Sub
End Sub

' Limpiar campos en opcion otros
Private Sub LimpiarCampos()
    ' Limpiar sólo si cmbDriver = 16
    If Me.cmbDriver = 16 Then
        Me.cmbCcauxiliar1 = Null
        Me.txtNombreAuxiliar1 = ""
    End If

    ' Limpiar el resto de campos en el orden indicado
    Me.txtObservaciones = ""
    Me.cmbDriver = Null
    Me.cmbTipoPago = Null
    Me.cmbProveedor = Null
    Call cmbDriver_AfterUpdate
    Call cmbTipoPago_AfterUpdate
End Sub



