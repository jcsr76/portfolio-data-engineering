VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Botones_Panico"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

Private Function LimpiarFormularioBotonesPanico()

    On Error GoTo LimpiarError

    ' Limpiar controles del formulario
    Me.cmbHora = Null
    Me.txtPlaca = Null
    Me.cmbTipoFlota = Null
    Me.txtEmpresaSatelital = Null
    Me.txtTiempoRespuesta = Null
    Me.txtUbicacionesVehiculo = Null
    Me.cmbNovedades = Null
    Me.txtObservaciones = Null
    Me.txtGestion = Null
    Me.txtFechaCierreNovedad = Null
    
    ' Deshabilitar el campo de fecha de cierre al limpiar
    Me.txtFechaCierreNovedad.Enabled = False

    Exit Function

LimpiarError:
    MsgBox "Error al limpiar campos del formulario: " & Err.Description, vbExclamation, "Error"
End Function

'========================================================================================
' FUNCIÓN AUXILIAR: Obtiene el ID del colaborador desde la vista de MySQL.
'========================================================================================
Private Function ObtenerIdColaborador(usuarioActual As String) As Long
    On Error GoTo ErrHandler
    
    Dim rs As ADODB.Recordset
    Dim sql As String
    
    ' Prepara la consulta SQL para la vista.
    sql = "SELECT id_colaborador FROM vista_colaboradores_usuarios WHERE usuario = '" & Replace(usuarioActual, "'", "''") & "'"
    
    Set rs = New ADODB.Recordset
    rs.Open sql, cnn, adOpenForwardOnly, adLockReadOnly
    
    ' Si encuentra el registro, devuelve el ID.
    If Not rs.EOF Then
        ObtenerIdColaborador = Nz(rs!id_colaborador, 0)
    Else
        ObtenerIdColaborador = 0 ' Devuelve 0 si no se encuentra el usuario.
    End If
    
    rs.Close
    Set rs = Nothing
    Exit Function

ErrHandler:
    ObtenerIdColaborador = 0 ' Devuelve 0 en caso de error.
    If Not rs Is Nothing Then
        If rs.State = adStateOpen Then rs.Close
        Set rs = Nothing
    End If
End Function

'========================================================================================
' EVENTO CLICK DEL BOTÓN: Guarda el registro del botón de pánico.
'========================================================================================
Private Sub btnGuardar_Click()
    On Error GoTo ErrHandler

    Dim usuarioActual As String
    Dim idColaborador As Long
    Dim cmd As ADODB.Command

    '--- 1. Validaciones de campos obligatorios ---
    If IsNull(Me.txtFecha) Then MsgBox "El campo 'Fecha' es obligatorio.", vbExclamation: Me.txtFecha.SetFocus: Exit Sub
    If IsNull(Me.cmbHora) Then MsgBox "El campo 'Hora' es obligatorio.", vbExclamation: Me.cmbHora.SetFocus: Exit Sub
    If Trim(Nz(Me.txtPlaca, "")) = "" Then MsgBox "El campo 'Placa' es obligatorio.", vbExclamation: Me.txtPlaca.SetFocus: Exit Sub
    If IsNull(Me.cmbTipoFlota) Then MsgBox "El campo 'Tipo de Flota' es obligatorio.", vbExclamation: Me.cmbTipoFlota.SetFocus: Exit Sub
    If Trim(Nz(Me.txtEmpresaSatelital, "")) = "" Then MsgBox "El campo 'Empresa Satelital' es obligatorio.", vbExclamation: Me.txtEmpresaSatelital.SetFocus: Exit Sub
    If Trim(Nz(Me.txtTiempoRespuesta, "")) = "" Then MsgBox "El campo 'Tiempo de Respuesta' es obligatorio.", vbExclamation: Me.txtTiempoRespuesta.SetFocus: Exit Sub
    If Trim(Nz(Me.txtUbicacionesVehiculo, "")) = "" Then MsgBox "El campo 'Ubicaciones del Vehículo' es obligatorio.", vbExclamation: Me.txtUbicacionesVehiculo.SetFocus: Exit Sub
    If IsNull(Me.cmbNovedades) Then MsgBox "El campo 'Novedades' es obligatorio.", vbExclamation: Me.cmbNovedades.SetFocus: Exit Sub
    
    '--- Validación condicional para Fecha de Cierre ---
    If Me.cmbNovedades.Value = "Si Reporta" And IsNull(Me.txtFechaCierreNovedad) Then
        MsgBox "El campo 'Fecha de Cierre' es obligatorio cuando Novedades es 'Si Reporta'.", vbExclamation
        Me.txtFechaCierreNovedad.SetFocus
        Exit Sub
    End If

    '--- 2. Obtener usuario actual ---
    usuarioActual = EstablecerUsuarioActual()
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual. El proceso se detendrá.", vbCritical
        Exit Sub
    End If

    '--- 3. Obtener ID del colaborador (Justo a Tiempo) ---
    idColaborador = ObtenerIdColaborador(usuarioActual)
    If idColaborador = 0 Then
        MsgBox "No se pudo encontrar el ID de colaborador para el usuario '" & usuarioActual & "'. Verifique que el usuario esté registrado en la vista de colaboradores.", vbExclamation
        Exit Sub
    End If
    
    '--- 4. Reconectar y abrir conexión si es necesario ---
    If Not VerificarYReconectarMySQL() Then Exit Sub
    If cnn Is Nothing Then Set cnn = New ADODB.Connection
    If cnn.State <> adStateOpen Then cnn.Open Con
    
    '--- 5. Preparar y ejecutar el procedimiento almacenado ---
    Set cmd = New ADODB.Command
    With cmd
        .ActiveConnection = cnn
        .CommandType = adCmdStoredProc
        .CommandText = "insertar_boton_panico"

        .Parameters.Append .CreateParameter("p_fecha", adDBDate, adParamInput, , Me.txtFecha)
        .Parameters.Append .CreateParameter("p_hora_solicitud_activacion", adDBTime, adParamInput, , Me.cmbHora)
        .Parameters.Append .CreateParameter("p_tiempo_respuesta", adInteger, adParamInput, , Nz(Me.txtTiempoRespuesta, 0))
        .Parameters.Append .CreateParameter("p_placa_vehiculo", adVarChar, adParamInput, 6, Me.txtPlaca)
        .Parameters.Append .CreateParameter("p_empresa_satelital", adVarChar, adParamInput, 50, Me.txtEmpresaSatelital)
        .Parameters.Append .CreateParameter("p_tipo_flota", adVarChar, adParamInput, 10, Me.cmbTipoFlota)
        .Parameters.Append .CreateParameter("p_ubicaciones_vehiculo", adLongVarChar, adParamInput, 65535, Me.txtUbicacionesVehiculo)
        .Parameters.Append .CreateParameter("p_novedades", adVarChar, adParamInput, 20, Me.cmbNovedades)
        .Parameters.Append .CreateParameter("p_observaciones", adLongVarChar, adParamInput, 65535, Me.txtObservaciones)
        .Parameters.Append .CreateParameter("p_gestion", adLongVarChar, adParamInput, 65535, Me.txtGestion)
        .Parameters.Append .CreateParameter("p_fecha_cierre_novedad", adDBDate, adParamInput, , IIf(IsNull(Me.txtFechaCierreNovedad), Null, Me.txtFechaCierreNovedad))
        .Parameters.Append .CreateParameter("p_controlador", adInteger, adParamInput, , idColaborador)
        .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)
        
        .Execute
    End With

    MsgBox "Registro de botón de pánico guardado correctamente.", vbInformation
    
    Set cmd = Nothing
    
    LimpiarFormularioBotonesPanico
    
    Exit Sub

'--- Manejo de Errores ---
ErrHandler:
    MsgBox "Ocurrió un error inesperado." & vbCrLf & vbCrLf & _
           "Error " & Err.Number & ": " & Err.Description, vbCritical, "Error en Guardado"
    
    On Error Resume Next
    Set cmd = Nothing
End Sub

Private Sub btnBorrarFormulario_Click()
    ' Limpiar Formulario
    Call LimpiarFormularioBotonesPanico
End Sub

Private Sub Form_Load()
    Dim i As Integer
    Dim hora As Date
    
    ' Limpiar Formulario
    Call LimpiarFormularioBotonesPanico
    
    ' Configura el ComboBox de hora para recibir una lista de valores
    Me.cmbHora.RowSourceType = "Value List"
    Me.cmbHora.RowSource = ""

    ' Llena la lista con horas desde 00:00 hasta 23:59 en intervalos de 1 minuto
    For i = 0 To 1439
        hora = TimeSerial(0, i, 0)
        Me.cmbHora.AddItem Format(hora, "hh:nn AM/PM")
    Next i
    
    ' Deshabilitar el campo de fecha de cierre al cargar
    Me.txtFechaCierreNovedad.Enabled = False
End Sub

Private Sub cmbNovedades_AfterUpdate()
    ' Habilita o deshabilita el campo de fecha de cierre según la selección
    If Me.cmbNovedades.Value = "Si Reporta" Then
        Me.txtFechaCierreNovedad.Enabled = True
    Else
        Me.txtFechaCierreNovedad.Enabled = False
        Me.txtFechaCierreNovedad.Value = Null ' Limpia el valor si se deshabilita
    End If
End Sub

Private Sub txtPlaca_AfterUpdate()
    Me.txtPlaca = LimpiarTextoMySQL(Me.txtPlaca)
End Sub

Private Sub txtEmpresaSatelital_AfterUpdate()
    Me.txtEmpresaSatelital = LimpiarTextoMySQL(Me.txtEmpresaSatelital)
End Sub

Private Sub txtUbicacionesVehiculo_AfterUpdate()
    Me.txtUbicacionesVehiculo = LimpiarTextoMySQL(Me.txtUbicacionesVehiculo)
End Sub

Private Sub txtObservaciones_AfterUpdate()
    Me.txtObservaciones = LimpiarTextoMySQL(Me.txtObservaciones)
End Sub

Private Sub txtGestion_AfterUpdate()
    Me.txtGestion = LimpiarTextoMySQL(Me.txtGestion)
End Sub



