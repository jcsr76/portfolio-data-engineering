VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Vehiculos_Terceros"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

'----------------------------------------------------------------------------------------
' FUNCIÓN: Limpiar el formulario (resetea todos los campos de vehículo)
'----------------------------------------------------------------------------------------
Private Function LimpiarFormularioTerceros()
    On Error GoTo LimpiarError

    ' --- Limpiar campos de VEHÍCULO ---
    Me.txtPlaca = Null
    Me.txtMarca = Null
    Me.txtModelo = Null
    Me.txtAnio = Null
    Me.cmbTipo = Null
    Me.cmbBase = Null
    Me.cmbEstatusVehiculo = Null
    Me.chkANS = False
    
    ' Poner el foco en el primer campo
    Me.txtPlaca.SetFocus

    Exit Function

LimpiarError:
    MsgBox "Error al limpiar los campos del formulario: " & Err.Description, vbExclamation, "Error"
End Function

'----------------------------------------------------------------------------------------
' EVENTOS DE BOTONES
'----------------------------------------------------------------------------------------
Private Sub btnBorrarFormulario_Click()
    Call LimpiarFormularioTerceros
End Sub

Private Sub btnGuardar_Click()
    On Error GoTo ErrHandler
    
    Dim ctrl As Control
    Dim camposFaltantes As String
    Dim nombreAmigable As String
    Dim rsTmp As DAO.Recordset
    Dim strJSON As String
    Dim cmd As ADODB.Command
    Dim usuarioActual As String

    '------------------------------------------
    ' 1) Validar campos obligatorios (Estilo dinámico)
    '------------------------------------------
    Dim listaControles As Variant
    listaControles = Array( _
        "txtPlaca", "cmbTipo", "txtMarca", "txtModelo", "txtAnio", _
        "cmbBase", "txtCapacidad", "cmbEstatusVehiculo", "txtFechaVencimientoSOAT" _
    )

    Dim i As Integer
    For i = LBound(listaControles) To UBound(listaControles)
        On Error Resume Next
        Set ctrl = Me.Controls(listaControles(i))
        On Error GoTo ErrHandler

        If Not ctrl Is Nothing Then
            nombreAmigable = Replace(Replace(Replace(ctrl.Name, "txt", ""), "cmb", ""), "chk", "")
            
            If (ctrl.ControlType = acTextBox And Trim(ctrl.Value & "") = "") Or _
               (ctrl.ControlType = acComboBox And (IsNull(ctrl.Value) Or Trim(ctrl.Value & "") = "")) Then
                camposFaltantes = camposFaltantes & vbCrLf & "- " & nombreAmigable
            End If
        End If
    Next i

    If Len(camposFaltantes) > 0 Then
        MsgBox "Debe diligenciar los siguientes campos del vehículo:" & vbCrLf & camposFaltantes, vbExclamation, "Campos incompletos"
        Exit Sub
    End If

    '------------------------------------------
    ' 2) Generar JSON desde la tabla local tbl_tmp_personas_roles
    '------------------------------------------
    Set rsTmp = CurrentDb.OpenRecordset("SELECT * FROM tbl_tmp_personas_roles", dbOpenSnapshot)
    
    If rsTmp.EOF Then
        MsgBox "Debe agregar al menos una persona relacionada (Propietario, Conductor o Tenedor) en el listado inferior.", vbExclamation, "Falta personal"
        rsTmp.Close: Exit Sub
    End If
    
    strJSON = "["
    Do While Not rsTmp.EOF
        strJSON = strJSON & "{" & _
            """nombre"":""" & LimpiarTextoMySQL(rsTmp!nombre) & """," & _
            """id"":""" & rsTmp!identificacion & """," & _
            """tel"":""" & rsTmp!telefono1 & """," & _
            """dir"":""" & LimpiarTextoMySQL(rsTmp!direccion) & """," & _
            """ciu"":" & Nz(rsTmp!ciudad, 0) & "," & _
            """rol"":""" & rsTmp!rol & """" & _
            "},"
        rsTmp.MoveNext
    Loop
    strJSON = Left(strJSON, Len(strJSON) - 1) & "]"
    rsTmp.Close

    '------------------------------------------
    ' 3) Verificar conexión MySQL y Usuario
    '------------------------------------------
    If Not VerificarYReconectarMySQL() Then Exit Sub
    If cnn Is Nothing Then Set cnn = New ADODB.Connection
    If cnn.State <> adStateOpen Then cnn.Open Con

    usuarioActual = EstablecerUsuarioActual
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual. No es posible continuar.", vbCritical
        Exit Sub
    End If
    
    '------------------------------------------
    ' 4) Ejecutar SP mediante objeto Command (Ajustado según ejemplo funcional)
    '------------------------------------------
    Set cmd = New ADODB.Command
    With cmd
        .ActiveConnection = cnn
        .CommandType = adCmdStoredProc
        .CommandText = "sp_insertar_moto_completa_terceros"
        
        ' Vehículo
        .Parameters.Append .CreateParameter("p_tipo", adVarChar, adParamInput, 10, Me.cmbTipo)
        .Parameters.Append .CreateParameter("p_placa", adVarChar, adParamInput, 10, UCase(Me.txtPlaca))
        .Parameters.Append .CreateParameter("p_marca", adVarWChar, adParamInput, 50, LimpiarTextoMySQL(Me.txtMarca))
        .Parameters.Append .CreateParameter("p_modelo", adVarWChar, adParamInput, 50, Me.txtModelo)
        .Parameters.Append .CreateParameter("p_anio", adInteger, adParamInput, , Me.txtAnio)
        .Parameters.Append .CreateParameter("p_id_base", adInteger, adParamInput, , Me.cmbBase)
        
        .Parameters.Append .CreateParameter("p_capacidad", adDecimal, adParamInput, , Nz(Me.txtCapacidad, 0))
        .Parameters("p_capacidad").Precision = 10
        .Parameters("p_capacidad").NumericScale = 2
        
        .Parameters.Append .CreateParameter("p_estado_v", adVarChar, adParamInput, 20, Me.cmbEstatusVehiculo)
        .Parameters.Append .CreateParameter("p_vencimiento_soat", adDBDate, adParamInput, , Me.txtFechaVencimientoSOAT)
        .Parameters.Append .CreateParameter("p_ans", adTinyInt, adParamInput, , IIf(Me.chkANS, 1, 0))
        
        ' JSON (Ajustado a adLongVarChar según tu ejemplo funcional)
        .Parameters.Append .CreateParameter("p_json_personas", adLongVarChar, adParamInput, Len(strJSON), strJSON)
        .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 50, usuarioActual)
        
        ' Salida
        .Parameters.Append .CreateParameter("p_id_vehiculo_gen", adInteger, adParamOutput)
        
        .Execute
    End With

    '------------------------------------------
    ' 5) Mensaje de éxito y Limpieza Final
    '------------------------------------------
    MsgBox "Vehículo y personal relacionado registrados correctamente.", vbInformation, "Éxito"
    
    CurrentDb.Execute "DELETE FROM tbl_tmp_personas_roles"
    Call LimpiarFormularioTerceros
    Me.sfm_tbl_tmp_personas_roles.Requery

    Exit Sub

ErrHandler:
    Dim errorMsg As String
    errorMsg = Err.Description
    
    If InStr(errorMsg, "Duplicate entry") > 0 Or InStr(errorMsg, "placa") > 0 Then
        MsgBox "La placa '" & Me.txtPlaca & "' ya se encuentra registrada en el sistema.", vbExclamation, "Vehículo duplicado"
    Else
        MsgBox "Error al registrar: " & Err.Number & " - " & errorMsg, vbCritical, "Error"
    End If
End Sub



'----------------------------------------------------------------------------------------
' EVENTO LOAD
'----------------------------------------------------------------------------------------
Private Sub Form_Load()
    ' Al abrir, simplemente nos aseguramos de que esté limpio y listo para escribir
    Call LimpiarFormularioTerceros
    
    ' Aseguramos que los botones de acción estén habilitados por defecto
    Me.btnBorrarFormulario.Enabled = True
    Me.btnGuardar.Enabled = True
End Sub

