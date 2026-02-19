VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Actividades_Operacion"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

'========================================================================================
' SECCIÓN 1: LÓGICA DE LA INTERFAZ DE USUARIO (SIN CAMBIOS)
'========================================================================================

Private Sub ActualizarControlesPorOpcion_Actividades()
    Dim opcion As Variant
    opcion = Me.Marco58.Value
    Dim habilitarPernocte As Boolean, habilitarPausas As Boolean
    If IsNull(opcion) Then
        habilitarPernocte = False
        habilitarPausas = False
        Me.btnBorrarBitacora.Enabled = False
        Me.btnGuardarBitacora.Enabled = False
    Else
        habilitarPernocte = (opcion = 1 Or opcion = 3)
        habilitarPausas = (opcion = 2 Or opcion = 3)
        Me.btnBorrarBitacora.Enabled = True
        Me.btnGuardarBitacora.Enabled = True
    End If
    Me.txtPlacaPernocte.Enabled = habilitarPernocte
    Me.txtLugarPernocte.Enabled = habilitarPernocte
    If Not habilitarPernocte Then Me.txtPlacaPernocte = Null: Me.txtLugarPernocte = Null
    Me.cmbHora.Enabled = habilitarPausas
    Me.txtHora.Enabled = habilitarPausas
    Me.txtMinutos.Enabled = habilitarPausas
    Me.cmbOrigen.Enabled = habilitarPausas
    Me.cmbDestino.Enabled = habilitarPausas
    Me.txtPlacaPausaActiva.Enabled = habilitarPausas
    Me.txtFechaReporte.Enabled = habilitarPausas
    Me.txtObservaciones.Enabled = habilitarPausas
    Me.chkPausaReal.Enabled = habilitarPausas
    Me.chkNovedad.Enabled = habilitarPausas
    If Not habilitarPausas Then
        Me.cmbHora = Null: Me.txtHora = Null: Me.txtMinutos = Null: Me.cmbOrigen = Null
        Me.cmbDestino = Null: Me.txtPlacaPausaActiva = Null: Me.txtFechaReporte = Null
        Me.txtObservaciones = Null: Me.chkPausaReal.Value = False: Me.chkNovedad.Value = False
    End If
End Sub

Private Function LimpiarFormularioActividades()
    On Error GoTo LimpiarError
    Me.cmbHora = Null: Me.txtHora = Null: Me.txtMinutos = Null: Me.cmbOrigen = Null
    Me.cmbDestino = Null: Me.txtPlacaPausaActiva = Null: Me.txtObservaciones = Null
    Me.txtPlacaPernocte = Null: Me.txtLugarPernocte = Null: Me.txtFechaReporte = Null
    Me.chkPausaReal = False: Me.chkNovedad = False: Me.Marco58 = Null
    Exit Function
LimpiarError:
    MsgBox "Error al limpiar formulario: " & Err.Description, vbExclamation, "Error"
End Function

Private Sub btnBorrarBitacora_Click()
    Call LimpiarFormularioActividades
    Call ActualizarControlesPorOpcion_Actividades
End Sub

Private Sub Form_Load()
    Dim i As Integer, hora As Date
    Call LimpiarFormularioActividades
    Me.cmbHora.RowSourceType = "Value List": Me.cmbHora.RowSource = ""
    For i = 0 To 1439
        hora = TimeSerial(0, i, 0)
        Me.cmbHora.AddItem Format(hora, "hh:nn AM/PM")
    Next i
    Call ActualizarControlesPorOpcion_Actividades
End Sub

Private Sub Marco58_AfterUpdate()
    Call ActualizarControlesPorOpcion_Actividades
End Sub

'========================================================================================
' SECCIÓN 2: LÓGICA DE GUARDADO DE DATOS (CON DEPURACIÓN MEJORADA)
'========================================================================================

Private Function CalcularTiempoConduccionDecimal() As Double
    On Error GoTo ErrHandler
    Dim horas As Double, minutos As Double
    horas = Nz(Me.txtHora, 0): minutos = Nz(Me.txtMinutos, 0)
    If minutos > 59 Then
        MsgBox "Los minutos no pueden ser mayores a 59.", vbExclamation
        CalcularTiempoConduccionDecimal = 0: Exit Function
    End If
    CalcularTiempoConduccionDecimal = horas + (minutos / 100)
    Exit Function
ErrHandler:
    CalcularTiempoConduccionDecimal = 0
End Function

Private Function ObtenerIdColaborador(usuarioActual As String) As Long
    On Error GoTo ErrHandler
    Dim rs As ADODB.Recordset, sql As String
    sql = "SELECT id_colaborador FROM vista_colaboradores_usuarios WHERE usuario = '" & Replace(usuarioActual, "'", "''") & "'"
    Set rs = New ADODB.Recordset
    rs.Open sql, cnn, adOpenForwardOnly, adLockReadOnly
    If Not rs.EOF Then ObtenerIdColaborador = Nz(rs!id_colaborador, 0) Else ObtenerIdColaborador = 0
    rs.Close: Set rs = Nothing
    Exit Function
ErrHandler:
    ObtenerIdColaborador = 0
    If Not rs Is Nothing Then If rs.State = adStateOpen Then rs.Close: Set rs = Nothing
End Function

Private Sub btnGuardarBitacora_Click()
    On Error GoTo ErrHandler

    Dim usuarioActual As String, idColaborador As Long
    Dim tiempoConduccion As Double, cmd As ADODB.Command
    Dim opcionSeleccionada As Variant

    opcionSeleccionada = Me.Marco58.Value
    usuarioActual = EstablecerUsuarioActual()
    If usuarioActual = "" Then MsgBox "No se pudo obtener el usuario actual.", vbCritical: Exit Sub

    idColaborador = ObtenerIdColaborador(usuarioActual)
    If idColaborador = 0 Then MsgBox "No se pudo encontrar el ID de colaborador para el usuario.", vbExclamation: Exit Sub
    
    If Not VerificarYReconectarMySQL() Then Exit Sub
    If cnn Is Nothing Then Set cnn = New ADODB.Connection
    If cnn.State <> adStateOpen Then cnn.Open Con
    
    '--- Procesar Pausas Activas ---
    If opcionSeleccionada = 2 Or opcionSeleccionada = 3 Then
        tiempoConduccion = CalcularTiempoConduccionDecimal()
        
        '--- INICIO DE DEPURACIÓN ---
        Debug.Print "--- Enviando a insertar_pausa_activa ---"
        Debug.Print "Placa: "; Me.txtPlacaPausaActiva.Value, "Origen: "; Me.cmbOrigen.Value, "Destino: "; Me.cmbDestino.Value
        Debug.Print "----------------------------------------"
        '--- FIN DE DEPURACIÓN ---

        Set cmd = New ADODB.Command
        With cmd
            .ActiveConnection = cnn
            .CommandType = adCmdStoredProc
            .CommandText = "insertar_pausa_activa"
            
            .Parameters.Append .CreateParameter("p_fecha", adDBDate, adParamInput, , IIf(IsNull(Me.txtFechaPausaActiva), Null, Me.txtFechaPausaActiva))
            .Parameters.Append .CreateParameter("p_hora", adDBTime, adParamInput, , IIf(IsNull(Me.cmbHora), Null, CDate(Me.cmbHora)))
            .Parameters.Append .CreateParameter("p_tiempo_conduccion", adNumeric, adParamInput, , tiempoConduccion)
            .Parameters(2).Precision = 10
            .Parameters(2).NumericScale = 2
            .Parameters.Append .CreateParameter("p_pausa_real", adTinyInt, adParamInput, , IIf(Me.chkPausaReal, 1, 0))
            .Parameters.Append .CreateParameter("p_origen", adInteger, adParamInput, , Me.cmbOrigen)
            .Parameters.Append .CreateParameter("p_destino", adInteger, adParamInput, , Me.cmbDestino)
            .Parameters.Append .CreateParameter("p_placa", adVarChar, adParamInput, 6, Me.txtPlacaPausaActiva)
            .Parameters.Append .CreateParameter("p_novedad", adTinyInt, adParamInput, , IIf(Me.chkNovedad, 1, 0))
            .Parameters.Append .CreateParameter("p_observaciones", adLongVarChar, adParamInput, 65535, Me.txtObservaciones)
            .Parameters.Append .CreateParameter("p_fecha_reporte", adDBDate, adParamInput, , IIf(IsNull(Me.txtFechaReporte), Null, Me.txtFechaReporte))
            .Parameters.Append .CreateParameter("p_controlador", adInteger, adParamInput, , idColaborador)
            .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)
            
            .Execute
        End With
        Set cmd = Nothing
    End If
    
    '--- Procesar Pernocte (Lógica futura) ---
    If opcionSeleccionada = 1 Or opcionSeleccionada = 3 Then
        ' (Aquí irá la lógica para Pernocte)
    End If

    MsgBox "Operación guardada correctamente.", vbInformation
    Call LimpiarFormularioActividades
    Call ActualizarControlesPorOpcion_Actividades
    
    Exit Sub

'--- Manejo de Errores Mejorado ---
ErrHandler:
    Dim error_desc As String
    error_desc = Err.Description
    
    ' Busca el mensaje personalizado de MySQL (SQLSTATE 45000)
    If InStr(error_desc, "45000") > 0 Then
        ' Extrae y muestra el mensaje de error real de la base de datos.
        error_desc = "Error al insertar en la base de datos:" & vbCrLf & vbCrLf & Mid(error_desc, InStr(error_desc, "MESSAGE_TEXT = ") + 15)
        MsgBox error_desc, vbCritical, "Error de Datos en MySQL"
    Else
        MsgBox "Ocurrió un error inesperado." & vbCrLf & vbCrLf & _
               "Error " & Err.Number & ": " & error_desc, vbCritical, "Error en Guardado"
    End If
    
    On Error Resume Next
    Set cmd = Nothing
End Sub


