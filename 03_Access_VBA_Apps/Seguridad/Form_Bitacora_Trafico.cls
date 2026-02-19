VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Bitacora_Trafico"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

Private Function LimpiarFormularioYTablas()

    On Error GoTo LimpiarError

    ' Limpiar controles del formulario
    Me.cmbTurno = Null
    Me.cmbControladorEntrega = Null
    Me.cmbControladorRecibe = Null
    Me.txtDetalleEscoltas = Null
    Me.txtObservaciones = Null
    Me.txtdetalle_id = Null

    ' Borrar registros de tablas locales
    DoCmd.SetWarnings False
    DoCmd.RunSQL "DELETE FROM trafico_avansat_provisional"
    DoCmd.RunSQL "DELETE FROM no_planillados_avansat_temporal"
    DoCmd.SetWarnings True
    
    ' Limpiar Sub-Formularios
    Me.[Subform trafico_avansat_provisional].Requery
    Me.[Subform no_planillados_avansat_temporal].Requery


    Exit Function

LimpiarError:
    MsgBox "Error al limpiar: " & Err.Description, vbExclamation, "Error"
    DoCmd.SetWarnings True
End Function

'------------------------------------------------------------
'  Formulario  Bitacora_Trafico  –  botón GuardarBitacora
'------------------------------------------------------------
Private Sub btnGuardarBitacora_Click()
    On Error GoTo ErrHandler

    Dim usuarioActual As String
    Dim cmd           As ADODB.Command
    Dim rsID          As ADODB.Recordset
    Dim sqlCall       As String
    Dim entradaID     As Long

    ' DAO recordsets
    Dim rsLocal  As DAO.Recordset
    Dim rsNoPlan As DAO.Recordset

    '--- 1. Usuario actual
    usuarioActual = EstablecerUsuarioActual()
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual.", vbCritical
        Exit Sub
    End If

    '--- 2. Validaciones de controles
    If IsNull(Me.txtFechaBitacora) Then MsgBox "La fecha es obligatoria.", vbExclamation: Me.txtFechaBitacora.SetFocus: Exit Sub
    If IsNull(Me.cmbTurno) Then MsgBox "El turno es obligatorio.", vbExclamation: Me.cmbTurno.SetFocus: Exit Sub
    If IsNull(Me.cmbControladorEntrega) Then MsgBox "El controlador que entrega es obligatorio.", vbExclamation: Me.cmbControladorEntrega.SetFocus: Exit Sub
    If IsNull(Me.cmbControladorRecibe) Then MsgBox "El controlador que recibe es obligatorio.", vbExclamation: Me.cmbControladorRecibe.SetFocus: Exit Sub

    '--- 2.1 VALIDACIÓN: Asegurar que trafico_avansat_provisional no esté vacío
    If DCount("*", "trafico_avansat_provisional", "Trim(Nz(cliente,''))<>'' AND Nz(cant_vehiculos,0)<>0") = 0 Then
        MsgBox "Debe ingresar al menos un registro en la tabla de tráfico Avansat o asegurese que la cantidad de vehículos es válida (Cliente y Cantidad de Vehículos).", vbExclamation
        Me.[Subform trafico_avansat_provisional].SetFocus
        Exit Sub
    End If

    '--- 2.2 NUEVA VALIDACIÓN: Asegurar que cant_vehiculos sea siempre positivo
    If DCount("*", "trafico_avansat_provisional", "Nz(cant_vehiculos, 0) <= 0 AND Trim(Nz(cliente,''))<>''") > 0 Then
        MsgBox "Se encontraron registros con una cantidad de vehículos inválida (cero o negativo). Por favor, corrija los datos antes de guardar.", vbExclamation
        Me.[Subform trafico_avansat_provisional].SetFocus
        Exit Sub
    End If

    '--- 3. Reconectar a MySQL
    If Not VerificarYReconectarMySQL() Then Exit Sub

    '--- 4. Abrir conexión si es necesario
    If cnn Is Nothing Then Set cnn = New ADODB.Connection
    If cnn.State <> adStateOpen Then cnn.Open Con

    '--- 5. Insertar en bitacora y obtener entradaID
    sqlCall = _
      "CALL insert_bitacora_operacion_trafico(" & _
      "'" & Format(Me.txtFechaBitacora, "yyyy\-mm\-dd") & "'," & _
      "'" & Me.cmbTurno & "'," & _
       Nz(Me.cmbControladorEntrega, 0) & "," & _
       Nz(Me.cmbControladorRecibe, 0) & "," & _
      "'" & Replace(Nz(Me.txtObservaciones, ""), "'", "''") & "'," & _
      "'" & usuarioActual & "');"

    Set rsID = cnn.Execute(sqlCall)
    If Not rsID.EOF Then
        entradaID = rsID!entrada_id
        Me.txtdetalle_id = entradaID
    Else
        MsgBox "No se pudo obtener el ID de la bitácora. El proceso se detendrá.", vbCritical
        Exit Sub
    End If
    rsID.Close: Set rsID = Nothing

    '--- 7. Procesar tabla trafico_avansat_provisional
    Set rsLocal = CurrentDb.OpenRecordset( _
        "SELECT * FROM trafico_avansat_provisional " & _
        "WHERE Trim(Nz(cliente,''))<>'' AND Nz(cant_vehiculos,0)>0")

    Do While Not rsLocal.EOF
        Dim cliente As String:  cliente = rsLocal!cliente
        Dim cantVeh As Long:    cantVeh = rsLocal!cant_vehiculos

        CurrentDb.Execute "UPDATE trafico_avansat_provisional SET entrada_id=" & entradaID & _
            " WHERE cliente='" & Replace(cliente, "'", "''") & "'", dbFailOnError

        Set cmd = New ADODB.Command
        With cmd
            .ActiveConnection = cnn
            .CommandType = adCmdStoredProc
            .CommandText = "insertar_trafico_avansat"
            .Parameters.Append .CreateParameter("p_entrada_id", adInteger, adParamInput, , entradaID)
            .Parameters.Append .CreateParameter("p_cliente", adVarChar, adParamInput, 100, cliente)
            .Parameters.Append .CreateParameter("p_cant_vehiculos", adInteger, adParamInput, , cantVeh)
            .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)
            .Execute
        End With
        Set cmd = Nothing
        rsLocal.MoveNext
    Loop
    rsLocal.Close: Set rsLocal = Nothing

    '--- 8. Procesar tabla no_planillados_avansat_temporal (Opcional)
    If DCount("*", "no_planillados_avansat_temporal", "Trim(Nz(placa,''))<>'' AND Trim(Nz(detalle,''))<>''") > 0 Then
    
        CurrentDb.Execute _
            "UPDATE no_planillados_avansat_temporal " & _
            "SET    entrada_id = " & entradaID & " " & _
            "WHERE  Trim(Nz(placa,''))<>'' AND Trim(Nz(detalle,''))<>''", dbFailOnError

        Set rsNoPlan = CurrentDb.OpenRecordset( _
            "SELECT placa, detalle " & _
            "FROM   no_planillados_avansat_temporal " & _
            "WHERE  entrada_id = " & entradaID)

        Do While Not rsNoPlan.EOF
            Dim placa   As String: placa = rsNoPlan!placa
            Dim detalle_no_planillado As String: detalle_no_planillado = rsNoPlan!Detalle

            Set cmd = New ADODB.Command
            With cmd
                .ActiveConnection = cnn
                .CommandType = adCmdStoredProc
                .CommandText = "insertar_no_planillados_avansat"
                .Parameters.Append .CreateParameter("p_entrada_id", adInteger, adParamInput, , entradaID)
                .Parameters.Append .CreateParameter("p_placa", adVarChar, adParamInput, 6, placa)
                .Parameters.Append .CreateParameter("p_detalle", adLongVarChar, adParamInput, 65535, detalle_no_planillado)
                .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)
                .Execute
            End With
            Set cmd = Nothing
            rsNoPlan.MoveNext
        Loop
        rsNoPlan.Close: Set rsNoPlan = Nothing

        Me.[Subform no_planillados_avansat_temporal].Requery
    End If
    
    '--- 9. PROCESAR NOVEDAD DE ESCOLTAS (Opcional)
    If Trim(Nz(Me.txtDetalleEscoltas, "")) <> "" Then
        Dim detalleEscoltas As String
        detalleEscoltas = Me.txtDetalleEscoltas.Value

        Set cmd = New ADODB.Command
        With cmd
            .ActiveConnection = cnn
            .CommandType = adCmdStoredProc
            .CommandText = "insertar_escoltas"
            .Parameters.Append .CreateParameter("p_entrada_id", adInteger, adParamInput, , entradaID)
            .Parameters.Append .CreateParameter("p_detalle", adLongVarChar, adParamInput, 65535, detalleEscoltas)
            .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)
            .Execute
        End With
        Set cmd = Nothing
    End If

    MsgBox "Registro guardado correctamente. Entrada ID = " & entradaID, vbInformation
    
    LimpiarFormularioYTablas
    
    Exit Sub

'--- Manejo de Errores
ErrHandler:
    Select Case Err.Number
        Case 3708
             MsgBox "Error 3708: Objeto Parameter mal definido. Verifique los tipos y tamaños de los parámetros al llamar al procedimiento almacenado.", vbCritical, "Error de Parámetro"
        Case 3464
            MsgBox "Error 3464: No coinciden los tipos de datos. " & _
                   "Verifique que el campo 'entrada_id' en la tabla temporal " & _
                   "sea de tipo Número (Entero Largo).", vbCritical, "Error de Tipo de Dato"
        Case -2147217900
            MsgBox "Error de base de datos: " & Err.Description, vbCritical
        Case 3704
            MsgBox "La consulta no devolvió datos.", vbExclamation
        Case Else
            MsgBox "Error " & Err.Number & ": " & Err.Description, vbCritical
    End Select

    On Error Resume Next
    If Not rsID Is Nothing Then If rsID.State = adStateOpen Then rsID.Close
    If Not rsLocal Is Nothing Then rsLocal.Close
    If Not rsNoPlan Is Nothing Then rsNoPlan.Close
    Set rsID = Nothing: Set rsLocal = Nothing: Set rsNoPlan = Nothing
End Sub

Private Sub btnBorrarBitacora_Click()
    ' Limpiar Formulario
    Call LimpiarFormularioYTablas
End Sub

Private Sub Form_Load()
    ' Limpiar Formulario
    Call LimpiarFormularioYTablas
End Sub



