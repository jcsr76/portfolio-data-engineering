VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Control_Estatus_Colaborador"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

' VARIABLE PÚBLICA GLOBAL para este formulario
Public idColaboradorActual As Long

' Consulta Dinámica para Filtros en Control Novedades
Private Const SQL_BASE_NOVEDADES As String = _
    "SELECT id_colaborador, id_cc, nombre_completo, estatus_colaborador, " & _
    "       total_novedades, novedades_abiertas " & _
    "FROM vista_colaboradores_con_novedades"

Private strFiltroNovedades As String

Private Const SQL_BASE_DETALLES As String = _
    "SELECT id_inactividad, id_colaborador, tipo_inactividad, fecha_inicio, fecha_fin, fecha_registro, registrado_por, estado_actual, estatus " & _
    "FROM vista_colaboradores_con_novedades_detalles"

Private strFiltroDetalles As String


Private Sub BTN_ActualizarNovedad_Click()
    On Error GoTo ErrHandler

    Dim cmd As ADODB.Command
    Dim usuarioActual As String
    Dim textoExistente As String
    Dim textoNuevo As String
    Dim textoObservacionesFinal As String
    Dim filasAfectadas As Integer

    '--- 1. Validaciones básicas ---
    If Nz(Me.txtIdInactividad, 0) = 0 Then
        MsgBox "Debe seleccionar una novedad en la lista de detalles antes de actualizar.", vbExclamation, "Novedad no seleccionada"
        Exit Sub
    End If

    If Nz(Me.txtIdColaboradorControlNovedades, 0) = 0 Then
        MsgBox "No se ha identificado el colaborador asociado a la novedad.", vbExclamation, "Colaborador no definido"
        Exit Sub
    End If

    If Nz(Me.cmbNuevoTipoInactividad.value, "") = "" Then
        MsgBox "Debe seleccionar el Tipo de Inactividad.", vbExclamation, "Dato requerido"
        Me.cmbNuevoTipoInactividad.SetFocus
        Exit Sub
    End If

    If Nz(Me.txtNuevaFechaIncial.value, "") = "" Then
        MsgBox "La nueva Fecha Inicial es requerida.", vbExclamation, "Dato requerido"
        Me.txtNuevaFechaIncial.SetFocus
        Exit Sub
    End If

    ' Validación opcional coherencia de fechas
    If Not IsNull(Me.txtNuevaFechaFinal.value) Then
        If CDate(Me.txtNuevaFechaFinal.value) < CDate(Me.txtNuevaFechaIncial.value) Then
            MsgBox "La nueva fecha final no puede ser anterior a la fecha inicial.", vbExclamation, "Rango de fechas inválido"
            Me.txtNuevaFechaFinal.SetFocus
            Exit Sub
        End If
    End If

    '--- 2. Conexión y usuario actual ---
    If Not VerificarYReconectarMySQL() Then Exit Sub
    If cnn Is Nothing Then Set cnn = New ADODB.Connection
    If cnn.State <> adStateOpen Then cnn.Open Con

    usuarioActual = EstablecerUsuarioActual
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual. No es posible continuar.", vbCritical
        Exit Sub
    End If

    '--- 3. Construir observaciones finales ---
    textoExistente = Nz(Me.txtObservacionesSelecion.value, "")
    textoNuevo = Trim(Nz(Me.txtAdicionarObservaciones.value, ""))

    If textoNuevo = "" Then
        ' No hay texto adicional: se conserva exactamente lo que ya estaba
        textoObservacionesFinal = textoExistente
    Else
        ' Hay texto nuevo: se concatena al final con firma y fecha/hora
        If textoExistente <> "" Then
            textoObservacionesFinal = textoExistente & vbCrLf & vbCrLf
        Else
            textoObservacionesFinal = ""
        End If

        textoObservacionesFinal = textoObservacionesFinal & _
                                  textoNuevo & vbCrLf & _
                                  "[" & usuarioActual & " - " & Format(Now, "yyyy-mm-dd HH:nn:ss") & "]"
    End If

        '--- 4. Ejecutar SP sp_actualizar_inactividad ---
    Set cmd = New ADODB.Command
    With cmd
        .ActiveConnection = cnn
        .CommandType = adCmdStoredProc
        .CommandText = "sp_actualizar_inactividad"

        ' 1. p_id_inactividad (INT)
        .Parameters.Append .CreateParameter("p_id_inactividad", adInteger, adParamInput, , Me.txtIdInactividad.value)
        
        ' 2. p_id_colaborador (INT)
        .Parameters.Append .CreateParameter("p_id_colaborador", adInteger, adParamInput, , Me.txtIdColaboradorControlNovedades.value)
        
        ' 3. p_tipo_inactividad (ENUM/String)
        .Parameters.Append .CreateParameter("p_tipo_inactividad", adVarChar, adParamInput, 50, Me.cmbNuevoTipoInactividad.value)
        
        ' 4. p_fecha_inicio (DATE)
        .Parameters.Append .CreateParameter("p_fecha_inicio", adDate, adParamInput, , CDate(Me.txtNuevaFechaIncial.value))
        
        ' 5. p_fecha_fin (DATE)
        .Parameters.Append .CreateParameter("p_fecha_fin", adDate, adParamInput, , IIf(Nz(Me.txtNuevaFechaFinal.value, "") = "", Null, CDate(Me.txtNuevaFechaFinal.value)))
        
        ' 6. p_observaciones (TEXT)
        .Parameters.Append .CreateParameter("p_observaciones", adLongVarChar, adParamInput, Len(textoObservacionesFinal), textoObservacionesFinal)
        
        ' 7. p_estado_actual (TINYINT) <--- ESTE FALTABA
        ' IMPORTANTE: Al usar .Value, Access envía el 1 o 0 de la columna oculta del combo.
        .Parameters.Append .CreateParameter("p_estado_actual", adTinyInt, adParamInput, , Me.cmbNuevoEstatus.value)
        
        ' 8. p_usuario (VARCHAR)
        .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)
        
        ' 9. p_filas_afectadas (OUT INT)
        .Parameters.Append .CreateParameter("p_filas_afectadas", adInteger, adParamOutput)

        .Execute
        filasAfectadas = .Parameters("p_filas_afectadas").value
    End With

    '--- 5. Interpretar resultado ---
    Select Case filasAfectadas
        Case 1
            MsgBox "La novedad se ha actualizado correctamente.", vbInformation, "Actualización exitosa"
            ' Refrescar lista de detalles y limpiar texto adicional
            
            AplicarFiltroNovedades
            
            CargarDetallesNovedades
            Me.txtAdicionarObservaciones.value = Null

        Case 0
            MsgBox "No se detectaron cambios en la novedad seleccionada.", vbInformation, "Sin cambios"

        Case Else   ' incluye -1 (error en SP)
            MsgBox "Ocurrió un error al actualizar la novedad. Revise el log en el servidor.", vbCritical, "Error en SP"
    End Select
    
    LimpiarControlesControlNovedades

ExitSub:
    On Error Resume Next
    Set cmd = Nothing
    Exit Sub

ErrHandler:
    MsgBox "Error en BTN_ActualizarNovedad: " & Err.Description, vbCritical, "Error de actualización"
    Resume ExitSub
End Sub

' Lógica del boton BTN_Borrar pestaña Novedades Colaborador
Private Sub BTN_Borrar_Click()
    LimpiarControlesPestañaNovedades
End Sub

Private Sub BTN_BorrarFormularioControlNovedades_Click()
    LimpiarControlesControlNovedades
End Sub

Private Sub BTN_BorrarRegistroNovedad_Click()
    On Error GoTo ErrHandler

    Dim cmd As ADODB.Command
    Dim usuarioActual As String
    Dim filasAfectadas As Integer
    Dim resp As VbMsgBoxResult

    '--- 1. Validaciones básicas ---
    If Nz(Me.txtIdInactividad, 0) = 0 Then
        MsgBox "Debe seleccionar una novedad en la lista de detalles antes de intentar borrarla.", _
               vbExclamation, "Novedad no seleccionada"
        Exit Sub
    End If

    If Nz(Me.txtIdColaboradorControlNovedades, 0) = 0 Then
        MsgBox "No se ha identificado el colaborador asociado a la novedad.", _
               vbExclamation, "Colaborador no definido"
        Exit Sub
    End If

    resp = MsgBox("Esta acción eliminará la novedad seleccionada." & vbCrLf & _
                  "¿Confirma que desea continuar?", _
                  vbQuestion + vbYesNo + vbDefaultButton2, "Confirmar eliminación")
    If resp <> vbYes Then Exit Sub

    '--- 2. Conexión y usuario actual ---
    If Not VerificarYReconectarMySQL() Then Exit Sub
    If cnn Is Nothing Then Set cnn = New ADODB.Connection
    If cnn.State <> adStateOpen Then cnn.Open Con

    usuarioActual = EstablecerUsuarioActual
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual. No es posible continuar.", vbCritical
        Exit Sub
    End If

    '--- 3. Ejecutar SP sp_eliminar_inactividad ---
    Set cmd = New ADODB.Command
    With cmd
        .ActiveConnection = cnn
        .CommandType = adCmdStoredProc
        .CommandText = "sp_eliminar_inactividad"

        .Parameters.Append .CreateParameter("p_id_inactividad", adInteger, adParamInput, , Me.txtIdInactividad.value)
        .Parameters.Append .CreateParameter("p_id_colaborador", adInteger, adParamInput, , Me.txtIdColaboradorControlNovedades.value)
        .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)
        .Parameters.Append .CreateParameter("p_filas_afectadas", adInteger, adParamOutput)

        .Execute
        filasAfectadas = .Parameters("p_filas_afectadas").value
    End With

        '--- 4. Interpretar resultado ---
    Select Case filasAfectadas
        Case 1
            MsgBox "La novedad se ha eliminado correctamente." & vbCrLf & vbCrLf & _
                   "Recuerde revisar y, si es necesario, ajustar manualmente el ESTATUS del colaborador " & _
                   "(Activo, Inactivo o Retirado) en el módulo de actualización de datos del colaborador.", _
                   vbInformation, "Eliminación exitosa"
            
            ' Refrescar lista de detalles
            CargarDetallesNovedades

        Case 0
            MsgBox "No se encontró la novedad a eliminar o ya fue eliminada.", _
                   vbInformation, "Sin cambios"

        Case Else   ' incluye -1 (error en SP)
            MsgBox "Ocurrió un error al eliminar la novedad. Revise el log en el servidor.", _
                   vbCritical, "Error en SP"
    End Select

    
    LimpiarControlesControlNovedades  ' limpiar controles de la pestaña

ExitSub:
    On Error Resume Next
    Set cmd = Nothing
    Exit Sub

ErrHandler:
    MsgBox "Error en BTN_BorrarRegistroNovedad: " & Err.Description, vbCritical, "Error de eliminación"
    Resume ExitSub
End Sub

Private Sub BTN_LimpiarFiltrosDetalles_Click()

    ' Limpiar combos de filtro de detalles
    Me.cmbTipoInactividad = Null
    Me.cmbTipoEstatus = Null

    ' Volver a cargar los detalles del colaborador actual sin filtros extra
    CargarDetallesNovedades

End Sub

' Lógica del boton botón Limpiar Filtros pestaña Contro Novedades
Private Sub BTN_LimpiarFiltrosControlNovedades_Click()

    ' Limpiar controles de filtro
    Me.cmbIdCC = Null
    Me.cmbNombreCompletoNovedades = Null
    Me.cmbEstatusColaboradorNovedades = Null
    Me.chkSoloNovedadesAbiertas = False

    ' Quitar condiciones de filtro
    strFiltroNovedades = ""

    ' Volver a cargar lista y combos con todos los datos
    AplicarFiltroNovedades

End Sub

'==================================================================================================
' EVENTO: Form_Load
' Función: Se dispara UNA VEZ al abrir el formulario.
'==================================================================================================
Private Sub Form_Load()
    Call InicializarFormulario          ' deja lstColaboradores con Activos

    strFiltroNovedades = ""             ' sin filtros al inicio
    AplicarFiltroNovedades              ' llena lstNovedadesColaborador

End Sub

'==================================================================================================
' EVENTO: Form_Activate
' Función: Se dispara cada vez que el formulario recupera el foco.
' Mantenerlo liviano para no rearmar todo el estado.
'==================================================================================================
Private Sub Form_Activate()
    ' Opcional: si no necesitas nada aquí, déjalo vacío.
End Sub

'==================================================================================================
' PROCEDIMIENTO PRIVADO: InicializarFormulario
' Función: Reinicia todos los controles y subformularios a su estado por defecto.
'==================================================================================================
Private Sub InicializarFormulario()
    Dim sql As String

    On Error Resume Next
    
    idColaboradorActual = 0

    Me.txtBuscarColaborador = Null
    Me.txtid_colaborador = Null
    Me.txtid_cc = Null
    Me.txtNombreCompleto = Null

    sql = "SELECT id_colaborador, id_cc, " & _
          "TRIM(primer_nombre & ' ' & segundo_nombre & ' ' & primer_apellido & ' ' & segundo_apellido) AS Nombre " & _
          "FROM vista_colaboradores " & _
          "WHERE estatus_colaborador = 'Activo' " & _
          "ORDER BY primer_nombre, primer_apellido;"

    Me.lstColaboradores.RowSource = sql
    Me.lstColaboradores.Requery
    
    Call LimpiarControlesPestañaNovedades
    Call LimpiarControlesPestañaControl
    
    Me.cmbTipoNovedad = Null
    Me.cmbTipoNovedad.Enabled = False
    
    Me.txtBuscarColaborador.SetFocus
    
        ' Controles de la pestaña Control de Novedades
    Me.txtIdCCSeleccionado = Null
    Me.txtNombreSeleccionado = Null
    Me.txtEstatusSeleccionado = Null
    Me.txtIdColaboradorControlNovedades = Null

    ' ListBox de detalles vacío
    Me.lstDetallesNovedades.RowSource = _
        "SELECT id_inactividad, id_colaborador, tipo_inactividad, fecha_inicio, fecha_fin, fecha_registro, estado_actual, estatus " & _
        "FROM vista_colaboradores_con_novedades_detalles WHERE 1=0;"
    Me.lstDetallesNovedades.Requery

    
    On Error GoTo 0
End Sub

'==================================================================================================
' PROCEDIMIENTO PRIVADO: LimpiarControlesPestañaNovedades
' Función: Limpia los controles de la Pestaña 0 (Novedades Colaborador)
'==================================================================================================
Private Sub LimpiarControlesPestañaNovedades()
    On Error Resume Next
    
    Me.txtIdColaboradorNovedades = Null
    Me.cmbTipoNovedad = Null
    Me.txtFechaInicial = Null
    Me.txtFechaFinal = Null
    Me.txtFechaTermincaionContrato = Null
    Me.txtMotivoTerminacionContrato = Null
    Me.txtObservaciones = Null
    Me.cmbPazySalvo = Null
    Me.txtIdColaboradorNovedades = Null
    
    ' Deshabilitar todos los controles de entrada
    Me.txtFechaInicial.Enabled = False
    Me.txtFechaFinal.Enabled = False
    Me.txtFechaTermincaionContrato.Enabled = False
    Me.txtMotivoTerminacionContrato.Enabled = False
    Me.txtObservaciones.Enabled = False
    Me.cmbTipoNovedad.Enabled = False
    Me.cmbPazySalvo.Enabled = False
    
    On Error GoTo 0
End Sub

'==================================================================================================
' PROCEDIMIENTO PRIVADO: LimpiarControlesPestañaControl
' Función: Limpia los controles de la Pestaña 1 (Control de Novedades)
'==================================================================================================
Private Sub LimpiarControlesPestañaControl()
    On Error Resume Next
    
    Me.txtIdColaboradorControlNovedades = Null
    ' Agregar aquí otros controles que existan en la pestaña 1
    
    On Error GoTo 0
End Sub

'==================================================================================================
' EVENTO: txtBuscarColaborador_Change
'==================================================================================================
Private Sub txtBuscarColaborador_Change()
    Dim sql As String
    Dim filtro As String

    filtro = Replace(Me.txtBuscarColaborador.Text, "'", "''")

    sql = "SELECT id_colaborador, id_cc, " & _
          "TRIM(primer_nombre & ' ' & segundo_nombre & ' ' & primer_apellido & ' ' & segundo_apellido) AS Nombre " & _
          "FROM vista_colaboradores " & _
          "WHERE estatus_colaborador = 'Activo' "
    
    If Len(filtro) > 0 Then
        sql = sql & "AND ((primer_nombre & ' ' & segundo_nombre & ' ' & primer_apellido & ' ' & segundo_apellido) LIKE '*" & filtro & "*' " & _
                    "OR id_cc LIKE '*" & filtro & "*') "
    End If
    
    sql = sql & "ORDER BY primer_nombre, primer_apellido;"

    Me.lstColaboradores.RowSource = sql
End Sub

'==================================================================================================
' EVENTO: lstColaboradores_Click
' FUNCIONALIDADES:
' 1. Cargar el id_colaborador en txtIdColaboradorNovedades (Pestaña 0)
' 2. Cargar el id_colaborador en txtIdColaboradorControlNovedades (Pestaña 1)
' 3. HABILITAR cmbTipoNovedad ya que hay colaborador seleccionado
'==================================================================================================
Private Sub lstColaboradores_Click()
    If Me.lstColaboradores.ListIndex <> -1 Then
        
        ' Cargar datos en controles de búsqueda
        Me.txtid_colaborador = Me.lstColaboradores.Column(0)
        Me.txtid_cc = Me.lstColaboradores.Column(1)
        Me.txtNombreCompleto = Me.lstColaboradores.Column(2)
        
        ' Guardar en variable global
        idColaboradorActual = CLng(Me.txtid_colaborador.value)
        
        ' Cargar en Pestaña 0 (Novedades Colaborador)
        Me.txtIdColaboradorNovedades = idColaboradorActual
        
        ' Habilitar cmbTipoNovedad ahora que hay colaborador
        Me.cmbTipoNovedad.Enabled = True
        Me.cmbTipoNovedad = Null
        Me.cmbTipoNovedad.SetFocus
        
        ' Deshabilitar y limpiar controles de entrada (espera selección de tipo)
        Call DeshabilitarTodosLosControlesDeEntrada

    End If
End Sub

'==================================================================================================
' EVENTO: cmbTipoNovedad_AfterUpdate
'==================================================================================================
Private Sub cmbTipoNovedad_AfterUpdate()
    On Error Resume Next
    
    Dim tipoNovedad As String
    
    tipoNovedad = Nz(Me.cmbTipoNovedad.value, "")
    
    If tipoNovedad = "" Then
        Call DeshabilitarTodosLosControlesDeEntrada
        Exit Sub
    End If
    
    Select Case tipoNovedad
        
        Case "Retiro"
            Me.txtFechaTermincaionContrato.Enabled = True
            Me.txtMotivoTerminacionContrato.Enabled = True
            Me.txtObservaciones.Enabled = True
            Me.cmbPazySalvo.Enabled = True
            
            Me.txtFechaInicial.Enabled = False
            Me.txtFechaInicial = Null
            Me.txtFechaFinal.Enabled = False
            Me.txtFechaFinal = Null
            
        Case "Licencia/Permiso", "Vacaciones", "Incapacidad", "Inasistencia"
            Me.txtFechaInicial.Enabled = True
            Me.txtFechaFinal.Enabled = True
            Me.txtObservaciones.Enabled = True
            
            Me.txtFechaTermincaionContrato.Enabled = False
            Me.txtFechaTermincaionContrato = Null
            Me.txtMotivoTerminacionContrato.Enabled = False
            Me.txtMotivoTerminacionContrato = Null
            Me.cmbPazySalvo.Enabled = False
            Me.cmbPazySalvo = Null
            
        Case Else
            Call DeshabilitarTodosLosControlesDeEntrada
            
    End Select
    
    On Error GoTo 0
End Sub

'==================================================================================================
' PROCEDIMIENTO PRIVADO: DeshabilitarTodosLosControlesDeEntrada
'==================================================================================================
Private Sub DeshabilitarTodosLosControlesDeEntrada()
    On Error Resume Next
    
    Me.txtFechaInicial.Enabled = False
    Me.txtFechaInicial = Null
    
    Me.txtFechaFinal.Enabled = False
    Me.txtFechaFinal = Null
    
    Me.txtFechaTermincaionContrato.Enabled = False
    Me.txtFechaTermincaionContrato = Null
    
    Me.txtMotivoTerminacionContrato.Enabled = False
    Me.txtMotivoTerminacionContrato = Null
    
    Me.txtObservaciones.Enabled = False
    Me.txtObservaciones = Null
    
    Me.cmbPazySalvo.Enabled = False
    Me.cmbPazySalvo = Null
    
    On Error GoTo 0
End Sub

'==================================================================================================
' EVENTO: TabControl_Change
'==================================================================================================
Private Sub TabControl_Change()
    If Nz(idColaboradorActual, 0) = 0 Then
        Exit Sub
    End If
    
    On Error Resume Next
    
    Select Case Me.TabControl.value
        Case 0
            ' Pestaña Novedades Colaborador
        Case 1
            ' Pestaña Control de Novedades
    End Select
    
    On Error GoTo 0
End Sub

'==================================================================================================
' BTN_Guardar_Click
'==================================================================================================
Private Sub BTN_Guardar_Click()
    On Error GoTo ErrHandler
    
    Dim tipoNovedad As String
    Dim idColaborador As Long
    
    tipoNovedad = Nz(Me.cmbTipoNovedad.value, "")
    idColaborador = Nz(Me.txtIdColaboradorNovedades.value, 0)
    
    If tipoNovedad = "Retiro" Then
        Call InsertarRetiro(idColaborador)
    Else
        Call InsertarInactividadTemporal(idColaborador, tipoNovedad)
    End If

ExitSub:
    Exit Sub

ErrHandler:
    MsgBox "Error inesperado en el proceso: " & Err.Description, vbCritical, "Error de VBA"
    Resume ExitSub
End Sub

'==================================================================================================
' InsertarInactividadTemporal
'==================================================================================================
Private Sub InsertarInactividadTemporal(ByVal idColaborador As Long, ByVal tipoNovedad As String)
    On Error GoTo ErrHandler
    
    Dim usuarioActual As String
    Dim resultadoSP As Integer
    Dim fechaInicial As Date
    Dim fechaFinal As Date
    Dim observaciones As String
    Dim sql As String
    Dim rst As ADODB.Recordset
    
    If idColaborador = 0 Then
        MsgBox "Debe seleccionar un colaborador de la lista principal.", vbExclamation, "Colaborador no seleccionado"
        Exit Sub
    End If
    
    If Nz(Me.txtFechaInicial.value, "") = "" Then
        MsgBox "La fecha inicial es requerida.", vbExclamation, "Campo incompleto"
        Me.txtFechaInicial.SetFocus
        Exit Sub
    End If
    
    If Nz(Me.txtFechaFinal.value, "") = "" Then
        MsgBox "La fecha final es requerida.", vbExclamation, "Campo incompleto"
        Me.txtFechaFinal.SetFocus
        Exit Sub
    End If
    
    fechaInicial = CDate(Me.txtFechaInicial.value)
    fechaFinal = CDate(Me.txtFechaFinal.value)
    
    If fechaFinal < fechaInicial Then
        MsgBox "La fecha final debe ser posterior a la fecha inicial.", vbExclamation, "Validación de fechas"
        Me.txtFechaFinal.SetFocus
        Exit Sub
    End If
    
    observaciones = Trim(Nz(Me.txtObservaciones.value, ""))
    If observaciones = "" Then
        MsgBox "Las observaciones son requeridas para registrar la inactividad.", vbExclamation, "Campo incompleto"
        Me.txtObservaciones.SetFocus
        Exit Sub
    End If
    
    If Not VerificarYReconectarMySQL() Then Exit Sub
    usuarioActual = EstablecerUsuarioActual
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual. No es posible continuar.", vbCritical
        Exit Sub
    End If
    
    cnn.Execute "SET @usuario_actual = '" & Replace(usuarioActual, "'", "''") & "';"
    
    sql = "CALL sp_insertar_inactividad(" & _
          idColaborador & "," & _
          "'" & tipoNovedad & "'," & _
          "'" & Format(fechaInicial, "yyyy-mm-dd") & "'," & _
          "'" & Format(fechaFinal, "yyyy-mm-dd") & "'," & _
          "'" & Replace(observaciones, "'", "''") & "'," & _
          "'" & usuarioActual & "'," & _
          "@p_resultado);"
    
    cnn.Execute "SET @p_resultado := 0;"
    cnn.Execute sql
    
    Set rst = New ADODB.Recordset
    Set rst = cnn.Execute("SELECT @p_resultado AS resultado;")
    If Not rst.EOF Then
        resultadoSP = rst.Fields("resultado").value
    End If
    rst.Close
    Set rst = Nothing
    
    Select Case resultadoSP
        Case 1
            MsgBox "La inactividad se ha registrado correctamente.", vbInformation, "Proceso completado"
            Call LimpiarControlesPestañaNovedades
            Me.lstColaboradores.Requery
            Me.cmbTipoNovedad = Null
            Me.cmbTipoNovedad.Enabled = False
        Case -1
            MsgBox "El SP devolvió código -1. El usuario no fue encontrado en vista_usuarios.", vbCritical, "SP sp_insertar_inactividad"
        Case Else
            MsgBox "El SP devolvió código: " & resultadoSP, vbExclamation, "Resultado inesperado"
    End Select

ExitSub:
    On Error Resume Next
    If Not rst Is Nothing Then rst.Close
    Set rst = Nothing
    Exit Sub

ErrHandler:
    MsgBox "Error en InsertarInactividadTemporal: " & Err.Description, vbCritical, "Error"
    Resume ExitSub
End Sub

'==================================================================================================
' InsertarRetiro
'==================================================================================================
Private Sub InsertarRetiro(ByVal idColaborador As Long)
    On Error GoTo ErrHandler
    
    Dim usuarioActual As String
    Dim fechaRetiro As Date
    Dim motivo As String
    Dim detalles As String
    Dim pazSalvo As String
    Dim sql As String
    Dim resultadoSP As Integer
    Dim rst As ADODB.Recordset
    
    If idColaborador = 0 Then
        MsgBox "Debe seleccionar un colaborador de la lista principal.", vbExclamation, "Colaborador no seleccionado"
        Exit Sub
    End If
    
    If Nz(Me.txtFechaTermincaionContrato.value, "") = "" Then
        MsgBox "La fecha de retiro es requerida.", vbExclamation, "Campo incompleto"
        Me.txtFechaTermincaionContrato.SetFocus
        Exit Sub
    End If
    If Not IsDate(Me.txtFechaTermincaionContrato.value) Then
        MsgBox "La fecha de retiro no es válida.", vbExclamation, "Fecha incorrecta"
        Me.txtFechaTermincaionContrato.SetFocus
        Exit Sub
    End If
    fechaRetiro = CDate(Me.txtFechaTermincaionContrato.value)
    
    motivo = Trim(Nz(Me.txtMotivoTerminacionContrato.value, ""))
    If motivo = "" Then
        MsgBox "El motivo de terminación del contrato es obligatorio.", vbExclamation, "Campo incompleto"
        Me.txtMotivoTerminacionContrato.SetFocus
        Exit Sub
    End If
    
    detalles = Trim(Nz(Me.txtObservaciones.value, ""))
    
    pazSalvo = Nz(Me.cmbPazySalvo.value, "")
    If pazSalvo = "" Then
        MsgBox "Debe seleccionar el estado de Paz y Salvo.", vbExclamation, "Campo incompleto"
        Me.cmbPazySalvo.SetFocus
        Exit Sub
    End If
    
    If Not VerificarYReconectarMySQL() Then Exit Sub
    usuarioActual = EstablecerUsuarioActual
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual. No es posible continuar.", vbCritical
        Exit Sub
    End If
    
    cnn.Execute "SET @usuario_actual = '" & Replace(usuarioActual, "'", "''") & "';"
    
    sql = "CALL sp_insertar_retiro(" & _
          idColaborador & "," & _
          "'" & Format(fechaRetiro, "yyyy-mm-dd") & "'," & _
          "'" & Replace(motivo, "'", "''") & "'," & _
          "'" & Replace(detalles, "'", "''") & "'," & _
          "'" & Replace(pazSalvo, "'", "''") & "'," & _
          "'" & usuarioActual & "'," & _
          "@p_resultado);"
    
    Debug.Print "SQL RETIRO: "; sql
    
    cnn.Execute "SET @p_resultado := 0;"
    cnn.Execute sql
    
    Set rst = New ADODB.Recordset
    Set rst = cnn.Execute("SELECT @p_resultado AS resultado;")
    If Not rst.EOF Then
        resultadoSP = rst.Fields("resultado").value
    End If
    rst.Close
    Set rst = Nothing
    
    Select Case resultadoSP
        Case 1
            MsgBox "El retiro se ha registrado correctamente.", vbInformation, "Proceso completado"
            Call LimpiarControlesPestañaNovedades
            Me.lstColaboradores.Requery
            Me.cmbTipoNovedad = Null
            Me.cmbTipoNovedad.Enabled = False
        Case -1
            MsgBox "El SP devolvió código -1. El usuario no fue encontrado en vista_usuarios.", vbCritical, "SP sp_insertar_retiro"
        Case Else
            MsgBox "El SP devolvió código: " & resultadoSP, vbExclamation, "Resultado inesperado"
    End Select

ExitSub:
    On Error Resume Next
    If Not rst Is Nothing Then rst.Close
    Set rst = Nothing
    Exit Sub

ErrHandler:
    MsgBox "Error en InsertarRetiro: " & Err.Description, vbCritical, "Error"
    Resume ExitSub
End Sub

' Cargar lista completa de colaboradores con novedades
Private Sub CargarNovedadesColaborador()
    strFiltroNovedades = ""
    AplicarFiltroNovedades
End Sub

Private Sub AplicarFiltroNovedades()

    Dim sqlFinal As String

    If strFiltroNovedades <> "" Then
        sqlFinal = SQL_BASE_NOVEDADES & " WHERE " & strFiltroNovedades & " ORDER BY nombre_completo"
    Else
        sqlFinal = SQL_BASE_NOVEDADES & " ORDER BY nombre_completo"
    End If

    Me.lstNovedadesColaborador.RowSource = sqlFinal
    Me.lstNovedadesColaborador.Requery

    ActualizarCombosNovedades sqlFinal

End Sub

' cargar los origenes de fila de los controles tipo combobox enla pestaña Control Novedades de forma dinámica
Private Sub ActualizarCombosNovedades(ByVal sqlLista As String)

    Dim sqlIdCC As String
    Dim sqlNombre As String
    Dim sqlEstatus As String
    Dim vIdCC As Variant
    Dim vNombre As Variant
    Dim vEstatus As Variant

    ' Guardar selección actual
    vIdCC = Me.cmbIdCC.value
    vNombre = Me.cmbNombreCompletoNovedades.value
    vEstatus = Me.cmbEstatusColaboradorNovedades.value

    ' Distintos id_cc
    sqlIdCC = "SELECT DISTINCT id_cc FROM (" & sqlLista & ") AS Q " & _
              "WHERE id_cc IS NOT NULL ORDER BY id_cc;"
    Me.cmbIdCC.RowSource = sqlIdCC
    Me.cmbIdCC.Requery
    Me.cmbIdCC.value = vIdCC   ' intenta restaurar

    ' Distintos nombres completos
    sqlNombre = "SELECT DISTINCT nombre_completo FROM (" & sqlLista & ") AS Q " & _
                "WHERE nombre_completo IS NOT NULL ORDER BY nombre_completo;"
    Me.cmbNombreCompletoNovedades.RowSource = sqlNombre
    Me.cmbNombreCompletoNovedades.Requery
    Me.cmbNombreCompletoNovedades.value = vNombre

    ' Distintos estatus
    sqlEstatus = "SELECT DISTINCT estatus_colaborador FROM (" & sqlLista & ") AS Q " & _
                 "WHERE estatus_colaborador IS NOT NULL ORDER BY estatus_colaborador;"
    Me.cmbEstatusColaboradorNovedades.RowSource = sqlEstatus
    Me.cmbEstatusColaboradorNovedades.Requery
    Me.cmbEstatusColaboradorNovedades.value = vEstatus

End Sub

' Aplicar Filtro de cmbIdCC
Private Sub cmbIdCC_AfterUpdate()
    RecalcularFiltroNovedades
    AplicarFiltroNovedades
End Sub

' Aplicar Filtro de cmbNombreCompletoNovedades
Private Sub cmbNombreCompletoNovedades_AfterUpdate()
    RecalcularFiltroNovedades
    AplicarFiltroNovedades
End Sub

' Aplicar Filtro de cmbEstatusColaboradorNovedades
Private Sub cmbEstatusColaboradorNovedades_AfterUpdate()
    RecalcularFiltroNovedades
    AplicarFiltroNovedades
End Sub

' Aplicar Filtro de chkSoloNovedadesAbiertas
Private Sub chkSoloNovedadesAbiertas_AfterUpdate()
    RecalcularFiltroNovedades
    AplicarFiltroNovedades
End Sub

Private Sub cmbTipoInactividad_AfterUpdate()
    CargarDetallesNovedades
End Sub

Private Sub cmbTipoEstatus_AfterUpdate()
    CargarDetallesNovedades
End Sub

' Manejo Dinámico de los Filtros en la pestaña Control Novedades
Private Sub RecalcularFiltroNovedades()

    strFiltroNovedades = ""

    ' id_cc
    If Not IsNull(Me.cmbIdCC) And Me.cmbIdCC <> "" Then
        strFiltroNovedades = strFiltroNovedades & "id_cc = '" & _
                             Replace(Me.cmbIdCC, "'", "''") & "'"
    End If

    ' nombre_completo (LIKE)
    If Not IsNull(Me.cmbNombreCompletoNovedades) And Me.cmbNombreCompletoNovedades <> "" Then
        If strFiltroNovedades <> "" Then strFiltroNovedades = strFiltroNovedades & " AND "
        strFiltroNovedades = strFiltroNovedades & "nombre_completo LIKE '*" & _
                             Replace(Me.cmbNombreCompletoNovedades, "'", "''") & "*'"
    End If

    ' estatus_colaborador
    If Not IsNull(Me.cmbEstatusColaboradorNovedades) And Me.cmbEstatusColaboradorNovedades <> "" Then
        If strFiltroNovedades <> "" Then strFiltroNovedades = strFiltroNovedades & " AND "
        strFiltroNovedades = strFiltroNovedades & "estatus_colaborador = '" & _
                             Replace(Me.cmbEstatusColaboradorNovedades, "'", "''") & "'"
    End If

    ' Solo novedades abiertas
    If Me.chkSoloNovedadesAbiertas = True Then
        If strFiltroNovedades <> "" Then strFiltroNovedades = strFiltroNovedades & " AND "
        strFiltroNovedades = strFiltroNovedades & "novedades_abiertas > 0"
    End If

End Sub

Private Sub lstNovedadesColaborador_Click()

    If Me.lstNovedadesColaborador.ListIndex = -1 Then Exit Sub

    ' Columnas según SQL_BASE_NOVEDADES
    ' 0 = id_colaborador
    ' 1 = id_cc
    ' 2 = nombre_completo
    ' 3 = estatus_colaborador

    Me.txtIdCCSeleccionado = Me.lstNovedadesColaborador.Column(1)
    Me.txtNombreSeleccionado = Me.lstNovedadesColaborador.Column(2)
    Me.txtEstatusSeleccionado = Me.lstNovedadesColaborador.Column(3)
    Me.txtIdColaboradorControlNovedades = Me.lstNovedadesColaborador.Column(0)
    
    CargarDetallesNovedades

End Sub

' cargar los datos en los detalles de la Novedad
Private Sub CargarDetallesNovedades()

    Dim sqlFinal As String
    Dim idColab As Long

    idColab = Nz(Me.txtIdColaboradorControlNovedades, 0)

    If idColab = 0 Then
        ' Sin colaborador: lista vacía
        Me.lstDetallesNovedades.RowSource = SQL_BASE_DETALLES & " WHERE 1=0;"
        Me.lstDetallesNovedades.Requery
        Me.txtIdInactividad = Null
        Me.txtObservacionesSelecion = Null
        Exit Sub
    End If

    ' Filtro base obligatorio por colaborador
    strFiltroDetalles = "id_colaborador = " & idColab

    ' Añadir filtros de los combos
    RecalcularFiltroDetalles

    sqlFinal = SQL_BASE_DETALLES & " WHERE " & strFiltroDetalles & " ORDER BY fecha_inicio DESC;"

    Me.lstDetallesNovedades.RowSource = sqlFinal
    Me.lstDetallesNovedades.Requery
    
    

    ' Limpiar selección de detalle y observaciones
    Me.txtIdInactividad = Null
    Me.txtObservacionesSelecion = Null

End Sub

' Filtros sobre lstDetallesNovedades (tipo_inactividad y estatus)
Private Sub RecalcularFiltroDetalles()

    ' En este punto strFiltroDetalles ya contiene "id_colaborador = X"

    ' tipo_inactividad
    If Not IsNull(Me.cmbTipoInactividad) And Me.cmbTipoInactividad <> "" Then
        strFiltroDetalles = strFiltroDetalles & " AND tipo_inactividad = '" & _
                            Replace(Me.cmbTipoInactividad, "'", "''") & "'"
    End If

    ' estatus (campo estatus de la vista de detalles)
    If Not IsNull(Me.cmbTipoEstatus) And Me.cmbTipoEstatus <> "" Then
        strFiltroDetalles = strFiltroDetalles & " AND estatus = '" & _
                            Replace(Me.cmbTipoEstatus, "'", "''") & "'"
    End If

End Sub


Private Sub lstDetallesNovedades_Click()

    Dim idIna As Long
    Dim rs As DAO.Recordset
    Dim sqlObs As String

    If Me.lstDetallesNovedades.ListIndex = -1 Then
        Me.txtIdInactividad = Null
        Me.txtObservacionesSelecion = Null
        Me.cmbNuevoTipoInactividad = Null
        Me.txtNuevaFechaIncial = Null
        Me.txtNuevaFechaFinal = Null
        Me.cmbNuevoEstatus = Null
        Exit Sub
    End If

    ' Columnas según SQL_BASE_DETALLES
    ' 0 = id_inactividad
    ' 2 = tipo_inactividad
    ' 3 = fecha_inicio
    ' 4 = fecha_fin
    ' 8 = estatus

    idIna = Nz(Me.lstDetallesNovedades.Column(0), 0)
    Me.txtIdInactividad = idIna

    ' Cargar datos en controles de edición
    Me.cmbNuevoTipoInactividad = Me.lstDetallesNovedades.Column(2)
    Me.txtNuevaFechaIncial = Me.lstDetallesNovedades.Column(3)
    Me.txtNuevaFechaFinal = Me.lstDetallesNovedades.Column(4)
    Me.cmbNuevoEstatus = Me.lstDetallesNovedades.Column(7)

    If idIna = 0 Then
        Me.txtObservacionesSelecion = Null
        Exit Sub
    End If

    ' Buscar observaciones en vista_tbl_inactividades
    sqlObs = "SELECT observaciones FROM vista_tbl_inactividades " & _
             "WHERE id_inactividad = " & idIna & ";"

    Set rs = CurrentDb.OpenRecordset(sqlObs, dbOpenSnapshot)
    If Not rs.EOF Then
        Me.txtObservacionesSelecion = Nz(rs!observaciones, "")
    Else
        Me.txtObservacionesSelecion = ""
    End If
    rs.Close
    Set rs = Nothing

End Sub

Private Sub LimpiarControlesControlNovedades()

    ' Controles de cabecera de la pestaña Control de Novedades
    Me.txtIdCCSeleccionado = Null
    Me.txtNombreSeleccionado = Null
    Me.txtEstatusSeleccionado = Null
    Me.txtIdColaboradorControlNovedades = Null

    ' Filtros de la sección superior (pero SIN tocar lstNovedadesColaborador)
    Me.cmbIdCC = Null
    Me.cmbNombreCompletoNovedades = Null
    Me.cmbEstatusColaboradorNovedades = Null
    Me.chkSoloNovedadesAbiertas = False

    ' Listado de detalles y filtros de detalles
    Me.cmbTipoInactividad = Null
    Me.cmbTipoEstatus = Null
    Me.lstDetallesNovedades.RowSource = SQL_BASE_DETALLES & " WHERE 1=0;"
    Me.lstDetallesNovedades.Requery

    ' Campos de detalle seleccionados / edición
    Me.txtIdInactividad = Null
    Me.txtObservacionesSelecion = Null
    Me.cmbNuevoTipoInactividad = Null
    Me.txtNuevaFechaIncial = Null
    Me.txtNuevaFechaFinal = Null
    Me.cmbNuevoEstatus = Null
    Me.txtAdicionarObservaciones = Null

    ' Reiniciar variables de filtro de la pestaña
    strFiltroNovedades = ""
    strFiltroDetalles = ""

End Sub


