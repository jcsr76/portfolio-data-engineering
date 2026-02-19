VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Conciliacion_Operacion"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

'----------------------------
' Filtrar ListBoxOperaciones según Fecha, Base, Sector, Servicio y Driver
'----------------------------
Private Sub FiltrarListBoxOperaciones()
    Dim strSQL            As String
    Dim whereClause       As String
    Dim fechaFiltro       As String
    Dim baseFiltro        As String
    Dim sectorFiltro      As String
    Dim servicioFiltro    As String
    Dim driverFiltro      As String
    Dim placaFiltro       As String


    ' Comenzamos la cláusula WHERE con una cadena vacía que siempre es verdadera
    whereClause = "1=1"  ' Siempre verdadero para incluir todos los registros inicialmente
    
    ' 1) Filtro de fecha (si existe)
    If Not IsNull(Me.txtFechaFiltro) And Me.txtFechaFiltro <> "" Then
        fechaFiltro = Format(Me.txtFechaFiltro, "yyyy-mm-dd")
        whereClause = whereClause & " AND O.fecha = #" & fechaFiltro & "#"
    End If

    ' 2) Filtro de base (si existe)
    If Not IsNull(Me.cmbBase.Value) And Me.cmbBase.Value <> "" Then
        baseFiltro = Me.cmbBase.Value
        whereClause = whereClause & " AND O.bases = '" & Replace(baseFiltro, "'", "''") & "'"
    End If

    ' 3) Filtro de sector (si existe)
    If Not IsNull(Me.cmbSector.Value) And Me.cmbSector.Value <> "" Then
        sectorFiltro = Me.cmbSector.Value
        whereClause = whereClause & " AND O.sector = '" & Replace(sectorFiltro, "'", "''") & "'"
    End If

    ' 4) Filtro de servicio (si existe)
    If Not IsNull(Me.cmbServicio.Value) And Me.cmbServicio.Value <> "" Then
        servicioFiltro = Me.cmbServicio.Value
        whereClause = whereClause & " AND O.Servicio = '" & Replace(servicioFiltro, "'", "''") & "'"
    End If

    ' 5) Filtro de driver (si existe)
    If Not IsNull(Me.cmbDriver.Value) And Me.cmbDriver.Value <> "" Then
        driverFiltro = Me.cmbDriver.Value
        whereClause = whereClause & " AND O.Driver = '" & Replace(driverFiltro, "'", "''") & "'"
    End If

    ' 6) Filtro de placa (si existe)
    If Not IsNull(Me.cmbPlaca.Value) And Me.cmbPlaca.Value <> "" Then
        placaFiltro = Me.cmbPlaca.Value
        whereClause = whereClause & " AND O.placa = '" & Replace(placaFiltro, "'", "''") & "'"
    End If

    ' 7) Asegurarse de que Hora_Inicio y Hora_Final no sean NULL
    whereClause = whereClause & " AND O.hora_inicio IS NOT NULL AND O.hora_final IS NOT NULL"

    ' 8) Construir la consulta SQL con SELECT * y la cláusula WHERE dinámica
    strSQL = "SELECT * FROM vista_conciliacion_operaciones O " & _
             "WHERE " & whereClause & " " & _
             "ORDER BY O.fecha ASC, CDate(O.hora_inicio) ASC;"

    ' 9) Asignamos la consulta SQL como fuente de datos del ListBox
    Me.lstOperaciones.RowSource = strSQL
    Me.lstOperaciones.Requery
    
    ' 10) Actualizar el ComboBox de placas después de filtrar
    ActualizarComboPlacas
End Sub

' Acciones al dar clic en el boton actualizar
Private Sub btnActualizar_Click()
    On Error GoTo ErrHandler

    ' ===============================
    ' VALIDACIONES DE HORAS (3 CASOS)
    ' ===============================
    Dim horaInicioRef As Date
    Dim horaFinalRef As Date
    Dim horaInicioNueva As Date
    Dim horaFinalNueva As Date
    Dim tieneInicioNuevo As Boolean
    Dim tieneFinalNuevo As Boolean
    Dim cc_aux_1 As Variant
    Dim cc_aux_2 As Variant

    tieneInicioNuevo = (Not IsNull(Me.cmbEditarHoraInicio.Value) And Me.cmbEditarHoraInicio.Value <> "")
    tieneFinalNuevo = (Not IsNull(Me.cmbNuevaHoraFinal.Value) And Me.cmbNuevaHoraFinal.Value <> "")

    ' Caso 1: solo cmbEditarHoraInicio
    If tieneInicioNuevo And Not tieneFinalNuevo Then
        horaInicioNueva = CDate(Format(Me.cmbEditarHoraInicio.Value, "HH:mm:ss"))
        horaFinalRef = CDate(Format(Me.txtHoraFinal.Value, "HH:mm:ss"))
        If horaInicioNueva >= horaFinalRef Then
            MsgBox "La nueva hora de inicio debe ser anterior a la hora final existente.", vbExclamation
            Me.cmbEditarHoraInicio.Value = Null
            Exit Sub
        End If
    End If

    ' Caso 2: solo cmbNuevaHoraFinal
    If tieneFinalNuevo And Not tieneInicioNuevo Then
        horaFinalNueva = CDate(Format(Me.cmbNuevaHoraFinal.Value, "HH:mm:ss"))
        horaInicioRef = CDate(Format(Me.txtHoraInicio.Value, "HH:mm:ss"))
        If horaFinalNueva <= horaInicioRef Then
            MsgBox "La nueva hora final debe ser posterior a la hora de inicio existente.", vbExclamation
            Me.cmbNuevaHoraFinal.Value = Null
            Exit Sub
        End If
    End If

    ' Caso 3: ambos campos nuevos
    If tieneInicioNuevo And tieneFinalNuevo Then
        horaInicioNueva = CDate(Format(Me.cmbEditarHoraInicio.Value, "HH:mm:ss"))
        horaFinalNueva = CDate(Format(Me.cmbNuevaHoraFinal.Value, "HH:mm:ss"))
        If horaInicioNueva >= horaFinalNueva Then
            MsgBox "La nueva hora de inicio debe ser anterior a la nueva hora final.", vbExclamation
            Me.cmbEditarHoraInicio.Value = Null
            Me.cmbNuevaHoraFinal.Value = Null
            Exit Sub
        End If
    End If
    
    ' =================================
    ' VALIDACIÓN DE LOS CHECKBOXES
    ' =================================
    
    ' Validar chkBorrarCcAux1 y chkBorrarCcAux2
    If Not IsNull(Me.txtCcauxiliar2.Value) And Me.txtCcauxiliar2.Value <> "" Then
        ' Si chkBorrarCcAux1 está seleccionado y chkBorrarCcAux2 no lo está, mostrar advertencia
        If Me.chkBorrarCcAux1.Value = True And Me.chkBorrarCcAux2.Value = False Then
            MsgBox "Para eliminar al Auxiliar 1, debe eliminar también al Auxiliar 2.", vbExclamation
            Me.chkBorrarCcAux1.Value = False  ' Desmarcar chkBorrarCcAux1
            Exit Sub
        End If
    End If

    ' =================================
    ' LÓGICA DEL PROCEDIMIENTO
    ' =================================
    
    ' Verificar conexión antes de continuar
    If Not VerificarYReconectarMySQL() Then Exit Sub

    ' Variables
    Dim cmd As Object
    Dim operacion_id As Integer
    Dim tonelaje As Variant
    Dim borrar_cc_aux_1 As Integer
    Dim borrar_cc_aux_2 As Integer
    Dim hora_inicio As Variant
    Dim hora_final As Variant
    Dim horas_no_operativas As Variant

    ' Llamar a la función global para establecer la variable de sesión @usuario_actual
    EstablecerUsuarioActual  ' Llama a la función que establece @usuario_actual

    ' Obtener el valor de operacion_id
    operacion_id = Me.txtOperacion_id.Value

    ' Solo actualizar tonelaje si hay un valor
    If IsNull(Me.cmbEditarTonelaje.Value) Or Me.cmbEditarTonelaje.Value = "" Then
        tonelaje = Null
    Else
        tonelaje = CInt(Me.cmbEditarTonelaje.Value)
    End If

    ' Convertir los checkboxes a enteros (0 o 1)
    borrar_cc_aux_1 = IIf(Me.chkBorrarCcAux1.Value, 1, 0)
    borrar_cc_aux_2 = IIf(Me.chkBorrarCcAux2.Value, 1, 0)

    ' Asignar valores a las horas solo si son proporcionados
    If Not IsNull(Me.cmbEditarHoraInicio.Value) And Me.cmbEditarHoraInicio.Value <> "" Then
        hora_inicio = Format(CDate(Me.cmbEditarHoraInicio.Value), "HH:mm:ss")
    Else
        hora_inicio = Null
    End If

    If Not IsNull(Me.cmbNuevaHoraFinal.Value) And Me.cmbNuevaHoraFinal.Value <> "" Then
        hora_final = Format(CDate(Me.cmbNuevaHoraFinal.Value), "HH:mm:ss")
    Else
        hora_final = Null
    End If

    If Not IsNull(Me.txtNuevaHorasNoOperativas.Value) And Me.txtNuevaHorasNoOperativas.Value <> "" Then
        horas_no_operativas = CDbl(Me.txtNuevaHorasNoOperativas.Value)
    Else
        horas_no_operativas = Null
    End If
    

    ' Asignación de auxiliares a variables locales
    If IsNull(Me.cmbCcNuevoauxiliar1.Value) Or Me.cmbCcNuevoauxiliar1.Value = "" Then
        cc_aux_1 = Null
    Else
        cc_aux_1 = Me.cmbCcNuevoauxiliar1.Value
    End If
    
    If IsNull(Me.cmbCcNuevoauxiliar2.Value) Or Me.cmbCcNuevoauxiliar2.Value = "" Then
        cc_aux_2 = Null
    Else
        cc_aux_2 = Me.cmbCcNuevoauxiliar2.Value
    End If
    
    ' Crear el comando para ejecutar el SP
    Set cmd = CreateObject("ADODB.Command")
    cmd.ActiveConnection = cnn
    cmd.CommandType = 4              ' <-- ESTA LÍNEA ES IMPRESCINDIBLE
    cmd.CommandText = "actualizar_operacion"
        
   
    cmd.Parameters.Append cmd.CreateParameter("@p_operacion_id", 3, 1, , operacion_id)
    cmd.Parameters.Append cmd.CreateParameter("@p_hora_inicio", 134, 1, , hora_inicio)
    cmd.Parameters.Append cmd.CreateParameter("@p_hora_final", 134, 1, , hora_final)
    cmd.Parameters.Append cmd.CreateParameter("@p_horas_no_operativas", 5, 1, , horas_no_operativas)
    cmd.Parameters.Append cmd.CreateParameter("@p_tonelaje", 3, 1, , tonelaje)
    cmd.Parameters.Append cmd.CreateParameter("@p_borrar_cc_aux_1", 3, 1, , borrar_cc_aux_1)
    cmd.Parameters.Append cmd.CreateParameter("@p_borrar_cc_aux_2", 3, 1, , borrar_cc_aux_2)
    cmd.Parameters.Append cmd.CreateParameter("@p_cc_aux_1", 200, 1, 20, cc_aux_1)
    cmd.Parameters.Append cmd.CreateParameter("@p_cc_aux_2", 200, 1, 20, cc_aux_2)

    
    cmd.Execute


    ' Mensaje de confirmación
    MsgBox "Operación actualizada correctamente.", vbInformation

    ' Limpiar
    Set cmd = Nothing
    
    ' Borrar los campos que usa el usuario
    BorrarCampos
    
    ' Actualizar la información en lstOperaciones
    FiltrarListBoxOperaciones
    
    ' Forzar la actualizacion de todas las consultas de los controles del formulario
    Call RequeryAllDataControls(Me)

    Exit Sub

ErrHandler:
    MsgBox "Error: " & Err.Description, vbCritical
    Set cmd = Nothing
End Sub

' Limpiar Formulario
Private Sub btnBorrarFormulario_Click()
    BorrarCampos
    ' Recupera y fija SIEMPRE la base del usuario actual desde la sesión
    Dim rsSesion As DAO.Recordset
    Dim valorBase As Variant
    Set rsSesion = CurrentDb.OpenRecordset("SELECT nombre_base FROM tbl_sesion_actual", dbOpenSnapshot)
    If Not rsSesion.EOF Then
        valorBase = rsSesion!nombre_base
        If Not IsNull(valorBase) And valorBase <> "" Then
            Me.cmbBase.Value = valorBase
            Call cmbBase_AfterUpdate
        End If
    End If
    rsSesion.Close
    FiltrarListBoxOperaciones
End Sub

' Actualizar el filtro con cmbDriver
Private Sub cmbDriver_AfterUpdate()
    FiltrarListBoxOperaciones
End Sub

' Actualizar el filtro con cmbPlaca
Private Sub cmbPlaca_AfterUpdate()
    FiltrarListBoxOperaciones
End Sub

' Actualizar el filtro con cmbSector
Private Sub cmbSector_AfterUpdate()
    FiltrarListBoxOperaciones
End Sub

' Actualizar el filtro con cmbServicio
Private Sub cmbServicio_AfterUpdate()
    ' Limpiar cmbDriver cuando cmbServicio se actualiza
    Me.cmbDriver.Value = ""  ' Limpiar el valor seleccionado
    Me.cmbDriver.RowSource = ""  ' Limpiar la lista de cmbDriver
    Me.cmbDriver.Requery  ' Recargar el control
    
    ' Verificar si cmbServicio tiene un valor seleccionado antes de proceder
    If Not IsNull(Me.cmbServicio.Value) And Me.cmbServicio.Value <> "" Then
        ' Obtener el servicio_id desde la columna 0 de cmbServicio
        Dim servicioId As String
        servicioId = Me.cmbServicio.Column(0) ' Columna 0 es servicio_id
        
        ' Actualizar el origen de fila de cmbDriver para filtrar por servicio_id
        If Not IsNull(servicioId) And servicioId <> "" Then
            Me.cmbDriver.RowSource = "SELECT driver_id, servicio_id, nombre FROM vista_driver " & _
                                     "WHERE servicio_id = " & servicioId & " " & _
                                     "ORDER BY nombre;"
            Me.cmbDriver.Requery
        End If
    Else
        ' Si cmbServicio está vacío, no aplicar ningún filtro y limpiar cmbDriver
        Me.cmbDriver.RowSource = ""  ' Limpiar la lista de cmbDriver
        Me.cmbDriver.Requery  ' Recargar el control
    End If

    ' Llamar a la función para filtrar el ListBox de operaciones
    FiltrarListBoxOperaciones
End Sub

' Procesos cuando se carga el formulario
Private Sub Form_Load()
    Dim i As Integer
    Dim hora As Date
    Dim i2 As Integer
    Dim hora2 As Date
    Dim rsSesion As DAO.Recordset
    Dim nombreBase As Variant

    '--- 1) Llenar combos de hora
    Me.cmbEditarHoraInicio.RowSourceType = "Value List"
    Me.cmbEditarHoraInicio.RowSource = ""
    For i = 0 To 1439
        hora = TimeSerial(0, i, 0)
        Me.cmbEditarHoraInicio.AddItem Format(hora, "hh:nn AM/PM")
    Next i

    Me.cmbNuevaHoraFinal.RowSourceType = "Value List"
    Me.cmbNuevaHoraFinal.RowSource = ""
    For i2 = 0 To 1439
        hora2 = TimeSerial(0, i2, 0)
        Me.cmbNuevaHoraFinal.AddItem Format(hora2, "hh:nn AM/PM")
    Next i2

    Me.cmbBase.Requery

    '--- 2) Asignar la base desde la sesión y RECARGAR combos de auxiliares después ---
    Set rsSesion = CurrentDb.OpenRecordset("SELECT nombre_base FROM tbl_sesion_actual", dbOpenSnapshot)
    If Not rsSesion.EOF Then
        nombreBase = rsSesion!nombre_base
        If Not IsNull(nombreBase) And nombreBase <> "" Then
            Me.cmbBase.Value = nombreBase
            Call cmbBase_AfterUpdate
        Else
            FiltrarListBoxOperaciones
        End If
    Else
        FiltrarListBoxOperaciones
    End If
    rsSesion.Close

    '--- 3) Solo aquí arma el Rowsource de los nuevos combos AUX con el valor real ---
    Dim baseActual As String
    baseActual = Me.cmbBase.Value
    
    Me.cmbCcNuevoauxiliar1.RowSource = "SELECT identificacion, nombre FROM vista_auxiliares_transporte_activo " & _
        "WHERE base_deprisa = '" & Replace(baseActual, "'", "''") & "' ORDER BY nombre;"
    Me.cmbCcNuevoauxiliar2.RowSource = "SELECT identificacion, nombre FROM vista_auxiliares_transporte_activo " & _
        "WHERE base_deprisa = '" & Replace(baseActual, "'", "''") & "' ORDER BY nombre;"
    Me.cmbCcNuevoauxiliar1.Requery
    Me.cmbCcNuevoauxiliar2.Requery

    '--- 4) El resto del código permanece igual ---
    Me.cmbBase.Locked = True

    If IsNull(Me.txtOperacion_id.Value) Or Me.txtOperacion_id.Value = "" Then
        Me.cmbEditarTonelaje.Enabled = False
        Me.cmbEditarHoraInicio.Enabled = False
        Me.cmbNuevaHoraFinal.Enabled = False
        Me.txtNuevaHorasNoOperativas.Enabled = False
        Me.cmbCcNuevoauxiliar1.Enabled = False
        Me.cmbCcNuevoauxiliar2.Enabled = False
        Me.chkBorrarCcAux1.Enabled = False
        Me.chkBorrarCcAux2.Enabled = False
    End If
End Sub

' Actualizar el filtro con cmbBase
Private Sub cmbBase_AfterUpdate()
    Me.cmbSector.Value = ""
    Me.cmbSector.RowSource = ""
    Me.cmbSector.Requery

    Dim baseSeleccionada As Variant
    If Not IsNull(Me.cmbBase.Value) And Me.cmbBase.Value <> "" Then
        If Me.cmbBase.ListIndex <> -1 Then
            baseSeleccionada = Me.cmbBase.Column(0) ' Columna 0 es base_id
        Else
            baseSeleccionada = Me.cmbBase.Value    ' En la mayoría de tus casos ya es el base_id
        End If

        If Not IsNull(baseSeleccionada) And baseSeleccionada <> "" Then
            Me.cmbSector.RowSource = "SELECT sector_id, base_id, sector " & _
                                     "FROM vista_sectores_deprisa " & _
                                     "WHERE base_id = " & baseSeleccionada & " " & _
                                     "ORDER BY sector;"
            Me.cmbSector.Requery
        End If
    Else
        Me.cmbSector.RowSource = ""
        Me.cmbSector.Requery
    End If

    FiltrarListBoxOperaciones
End Sub

' cargar datos del registro seleccionado por el usuario
Private Sub lstOperaciones_Click()
    ' Verificar si un ítem está seleccionado
    If Me.lstOperaciones.ListIndex <> -1 Then
        ' Obtener el operacion_id (primer valor de la columna de la lista)
        Dim operacionID As String
        operacionID = Me.lstOperaciones.Column(0, Me.lstOperaciones.ListIndex) ' Columna 0 es operacion_id
        
        ' Copiar los datos del registro seleccionado a los TextBox
        Me.txtOperacion_id.Value = operacionID ' Usando el nombre correcto del control
        Me.txtTonelaje.Value = Me.lstOperaciones.Column(7, Me.lstOperaciones.ListIndex) ' Columna 7 es Tonelaje
        Me.txtCcauxiliar1.Value = Me.lstOperaciones.Column(15, Me.lstOperaciones.ListIndex) ' Columna 15 es cc_aux_1
        Me.txtCcauxiliar2.Value = Me.lstOperaciones.Column(16, Me.lstOperaciones.ListIndex) ' Columna 16 es cc_aux_2
        Me.txtHoraInicio.Value = Me.lstOperaciones.Column(12, Me.lstOperaciones.ListIndex) ' Columna 12 es Hora_Inicio
        Me.txtHoraFinal.Value = Me.lstOperaciones.Column(13, Me.lstOperaciones.ListIndex) ' Columna 13 es Hora_Final
        Me.txtHorasNoOperativas.Value = Me.lstOperaciones.Column(14, Me.lstOperaciones.ListIndex) ' Columna 14 es horas_no_operativas
    End If
    
    ' Habilitar los controles si el usuario ya eligió un registro para editar
        Me.cmbEditarTonelaje.Enabled = True
        Me.cmbEditarHoraInicio.Enabled = True
        Me.cmbNuevaHoraFinal.Enabled = True
        Me.txtNuevaHorasNoOperativas.Enabled = True
        Me.cmbCcNuevoauxiliar1.Enabled = True
        Me.cmbCcNuevoauxiliar2.Enabled = True
        
    ' Validar si txtCcAuxiliar1 tiene un valor para habilitar chkBorrarCcAux1
    If Not IsNull(Me.txtCcauxiliar1.Value) And Me.txtCcauxiliar1.Value <> "" Then
        Me.chkBorrarCcAux1.Enabled = True
    Else
        Me.chkBorrarCcAux1.Enabled = False
    End If
    
    ' Validar si txtCcAuxiliar2 tiene un valor para habilitar chkBorrarCcAux2
    If Not IsNull(Me.txtCcauxiliar2.Value) And Me.txtCcauxiliar2.Value <> "" Then
        Me.chkBorrarCcAux2.Enabled = True
    Else
        Me.chkBorrarCcAux2.Enabled = False
    End If
    
End Sub

' Limpiar Formulario
Private Sub BorrarCampos()
    ' Limpiar los valores de los campos especificados
    Me.cmbEditarTonelaje.Value = Null
    Me.cmbEditarHoraInicio.Value = Null
    Me.cmbNuevaHoraFinal.Value = Null
    Me.txtNuevaHorasNoOperativas.Value = Null
    Me.chkBorrarCcAux1.Value = False
    Me.chkBorrarCcAux2.Value = False
    Me.txtOperacion_id.Value = Null
    Me.txtTonelaje.Value = Null
    Me.txtCcauxiliar1.Value = Null
    Me.txtCcauxiliar2.Value = Null
    Me.txtHoraInicio.Value = Null
    Me.txtHoraFinal.Value = Null
    Me.txtHorasNoOperativas.Value = Null
    Me.cmbSector.Value = Null
    Me.cmbPlaca.Value = Null
    Me.cmbServicio.Value = Null
    Me.cmbDriver.Value = Null
    Me.cmbCcNuevoauxiliar1.Value = Null
    Me.cmbCcNuevoauxiliar2.Value = Null
    
    ' Deshabilitar campos de edición
    Me.cmbEditarTonelaje.Enabled = False
    Me.cmbEditarHoraInicio.Enabled = False
    Me.cmbNuevaHoraFinal.Enabled = False
    Me.txtNuevaHorasNoOperativas.Enabled = False
    Me.chkBorrarCcAux1.Enabled = False
    Me.chkBorrarCcAux2.Enabled = False
    Me.cmbCcNuevoauxiliar1.Enabled = False
    Me.cmbCcNuevoauxiliar2.Enabled = False

End Sub

' función para actualizar los números de placa en cmbPlaca según el contenido lstOperaciones

Private Sub ActualizarComboPlacas()
    Dim rs As DAO.Recordset
    Dim strSQL As String
    Dim placas As New Collection
    Dim placa As Variant

    ' Forzar modo "Value List"
    Me.cmbPlaca.RowSourceType = "Value List"
    Me.cmbPlaca.RowSource = ""  ' Limpiar ComboBox antes de agregar nuevos valores
    
    ' Habilitar cmbPlaca si hay datos en lstOperaciones
    If Me.lstOperaciones.ListCount > 0 Then
        Me.cmbPlaca.Enabled = True
    Else
        Me.cmbPlaca.Enabled = False
    End If

    ' Construir WHERE dinámico
    Dim filtroWhere As String
    filtroWhere = ObtenerCondicionWhereOperaciones()

    ' Consulta SQL con filtros activos
    strSQL = "SELECT DISTINCT O.placa FROM vista_conciliacion_operaciones AS O WHERE " & filtroWhere & " ORDER BY O.placa;"

    Set rs = CurrentDb.OpenRecordset(strSQL, dbOpenSnapshot)

    ' Agregar las placas únicas al combo
    If Not rs.EOF Then
        Do While Not rs.EOF
            placa = rs.Fields("placa").Value
            On Error Resume Next
            placas.Add placa, CStr(placa)  ' Evita duplicados
            On Error GoTo 0
            rs.MoveNext
        Loop

        ' Agregar las placas al ComboBox
        For Each placa In placas
            Me.cmbPlaca.AddItem placa
        Next placa
    Else
        Me.cmbPlaca.AddItem "No hay placas disponibles"
        Me.cmbPlaca.Enabled = False
    End If

    rs.Close
    Set rs = Nothing
End Sub

' Funcion para obtener condiciones para actualizar la informacion de cnbPlaca

Private Function ObtenerCondicionWhereOperaciones() As String
    Dim whereClause As String
    Dim fechaFiltro As String
    Dim baseFiltro As String
    Dim sectorFiltro As String
    Dim servicioFiltro As String
    Dim driverFiltro As String

    whereClause = "1=1"

    If Not IsNull(Me.txtFechaFiltro) And Me.txtFechaFiltro <> "" Then
        fechaFiltro = Format(Me.txtFechaFiltro, "yyyy-mm-dd")
        whereClause = whereClause & " AND O.fecha = #" & fechaFiltro & "#"
    End If

    If Not IsNull(Me.cmbBase.Value) And Me.cmbBase.Value <> "" Then
        baseFiltro = Me.cmbBase.Value
        whereClause = whereClause & " AND O.bases = '" & Replace(baseFiltro, "'", "''") & "'"
    End If

    If Not IsNull(Me.cmbSector.Value) And Me.cmbSector.Value <> "" Then
        sectorFiltro = Me.cmbSector.Value
        whereClause = whereClause & " AND O.sector = '" & Replace(sectorFiltro, "'", "''") & "'"
    End If

    If Not IsNull(Me.cmbServicio.Value) And Me.cmbServicio.Value <> "" Then
        servicioFiltro = Me.cmbServicio.Value
        whereClause = whereClause & " AND O.Servicio = '" & Replace(servicioFiltro, "'", "''") & "'"
    End If

    If Not IsNull(Me.cmbDriver.Value) And Me.cmbDriver.Value <> "" Then
        driverFiltro = Me.cmbDriver.Value
        whereClause = whereClause & " AND O.Driver = '" & Replace(driverFiltro, "'", "''") & "'"
    End If

    ObtenerCondicionWhereOperaciones = whereClause
End Function

Private Sub txtFechaFiltro_AfterUpdate()
    FiltrarListBoxOperaciones
End Sub

' verificar que el id del auxiliar que se ingresa no exista ya en el registro
Private Sub cmbCcNuevoauxiliar1_AfterUpdate()
    If Not IsNull(Me.cmbCcNuevoauxiliar1.Value) And Me.cmbCcNuevoauxiliar1.Value <> "" Then
        If (Me.cmbCcNuevoauxiliar1.Value = Me.txtCcauxiliar1.Value) Or _
           (Me.cmbCcNuevoauxiliar1.Value = Me.txtCcauxiliar2.Value) Then
            MsgBox "El número de documento seleccionado ya está presente en el registro original. Seleccione uno diferente.", vbExclamation, "Dato repetido"
            Me.cmbCcNuevoauxiliar1.Value = Null
            Me.cmbCcNuevoauxiliar1.SetFocus
        Else
            Me.cmbCcNuevoauxiliar1.SetFocus
        End If
    Else
        Me.cmbCcNuevoauxiliar1.SetFocus
    End If
End Sub

' verificar que el id del auxiliar que se ingresa no exista ya en el registro
Private Sub cmbCcNuevoauxiliar2_AfterUpdate()
    If Not IsNull(Me.cmbCcNuevoauxiliar2.Value) And Me.cmbCcNuevoauxiliar2.Value <> "" Then
        If (Me.cmbCcNuevoauxiliar2.Value = Me.txtCcauxiliar1.Value) Or _
           (Me.cmbCcNuevoauxiliar2.Value = Me.txtCcauxiliar2.Value) Then
            MsgBox "El número de documento seleccionado ya está presente en el registro original. Seleccione uno diferente.", vbExclamation, "Dato repetido"
            Me.cmbCcNuevoauxiliar2.Value = Null
            Me.cmbCcNuevoauxiliar2.SetFocus
        Else
            Me.cmbCcNuevoauxiliar2.SetFocus
        End If
    Else
        Me.cmbCcNuevoauxiliar2.SetFocus
    End If
End Sub




