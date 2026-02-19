VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Registro_Contrato_Colaborador"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

Private Sub BTN_Borrar_Click()
    Call Limpiar_Formulario_Contrato
    Call RequeryAllDataControls(Me)
End Sub

'==================================================================================================
' EVENTO CLICK DEL BOTÓN GUARDAR (Versión Actualizada - Con parámetro OUT p_resultado)
'==================================================================================================
Private Sub BTN_Guardar_Click()
    On Error GoTo ErrHandler
    
    Dim cmd As ADODB.Command
    Dim usuarioActual As String
    Dim resultadoSP As Integer
    
    '--- 1. VALIDACIÓN DETALLADA DE CAMPOS OBLIGATORIOS ---
    If Nz(Me.txtid_colaborador, 0) = 0 Then
        MsgBox "Debe seleccionar un colaborador de la lista antes de continuar.", vbExclamation, "Faltan datos"
        Exit Sub
    End If
    If IsNull(Me.txtFechaIngreso) Then
        MsgBox "El campo 'Fecha de Ingreso' es obligatorio.", vbExclamation, "Faltan datos"
        Me.txtFechaIngreso.SetFocus
        Exit Sub
    End If
    If IsNull(Me.cmbFormaPago) Then
        MsgBox "El campo 'Forma de Pago' es obligatorio.", vbExclamation, "Faltan datos"
        Me.cmbFormaPago.SetFocus
        Exit Sub
    End If
    If IsNull(Me.cmbCentrocosto) Then
        MsgBox "El campo 'Centro de Costo' es obligatorio.", vbExclamation, "Faltan datos"
        Me.cmbCentrocosto.SetFocus
        Exit Sub
    End If
    If Nz(Me.txtSalarioBase, 0) <= 0 Then
        MsgBox "El campo 'Salario Base' es obligatorio y debe ser mayor que cero.", vbExclamation, "Dato inválido"
        Me.txtSalarioBase.SetFocus
        Exit Sub
    End If
    If Nz(Me.txtTurno, "") = "" Then
        MsgBox "El campo 'Turno' es obligatorio.", vbExclamation, "Faltan datos"
        Me.txtTurno.SetFocus
        Exit Sub
    End If
    If IsNull(Me.cmbTipoContrato) Then
        MsgBox "Debe seleccionar un 'Tipo de Contrato'.", vbExclamation, "Faltan datos"
        Me.cmbTipoContrato.SetFocus
        Exit Sub
    Else
        If Me.cmbTipoContrato.value = "Termino fijo" And IsNull(Me.txtFechaTerminacion) Then
            MsgBox "Para un contrato a 'Término fijo', la 'Fecha de Terminación' es obligatoria.", vbExclamation, "Faltan datos"
            Me.txtFechaTerminacion.SetFocus
            Exit Sub
        End If
    End If

    '--- 2. Conexión a MySQL y obtención de usuario ---
    If Not VerificarYReconectarMySQL() Then Exit Sub
    If cnn Is Nothing Then Set cnn = New ADODB.Connection
    If cnn.State <> adStateOpen Then cnn.Open Con
    usuarioActual = EstablecerUsuarioActual
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual. No es posible continuar.", vbCritical
        Exit Sub
    End If
    
    '--- 3. Configurar y Ejecutar el Procedimiento Almacenado ---
    Set cmd = New ADODB.Command
    With cmd
        .ActiveConnection = cnn
        .CommandType = adCmdStoredProc
        .CommandText = "sp_insertar_contrato"
        
        ' Asignación de Parámetros
        .Parameters.Append .CreateParameter("p_id_colaborador", adInteger, adParamInput, , Me.txtid_colaborador.value)
        .Parameters.Append .CreateParameter("p_fecha_ingreso", adDBDate, adParamInput, , Me.txtFechaIngreso.value)
        .Parameters.Append .CreateParameter("p_forma_pago", adVarChar, adParamInput, 20, Me.cmbFormaPago.value)
        .Parameters.Append .CreateParameter("p_id_centro_costo", adInteger, adParamInput, , Me.cmbCentrocosto.value)
        .Parameters.Append .CreateParameter("p_salario_base", adCurrency, adParamInput, , Me.txtSalarioBase.value)
        .Parameters.Append .CreateParameter("p_turno", adVarChar, adParamInput, 50, Me.txtTurno.value)
        
        ' Parámetros Opcionales de Contratos
        .Parameters.Append .CreateParameter("p_tipo_contrato", adVarChar, adParamInput, 50, Me.cmbTipoContrato.value)
        .Parameters.Append .CreateParameter("p_termino_meses", adDBDate, adParamInput, , Nz(Me.txtFechaTerminacion.value, Null))
        .Parameters.Append .CreateParameter("p_aux_alimentacion", adCurrency, adParamInput, , Nz(Me.txtAuxAlimentacion.value, Null))
        .Parameters.Append .CreateParameter("p_aux_transporte", adCurrency, adParamInput, , Nz(Me.txtAuxTransporte.value, Null))
        .Parameters.Append .CreateParameter("p_salario_integral", adTinyInt, adParamInput, , IIf(Nz(Me.chkSalarioIntegral.value, False), 1, 0))
        .Parameters.Append .CreateParameter("p_rodamiento", adCurrency, adParamInput, , Nz(Me.txtRodamiento.value, Null))
        .Parameters.Append .CreateParameter("p_contrato", adTinyInt, adParamInput, , IIf(Nz(Me.chkContratoOK.value, False), 1, 0))
        .Parameters.Append .CreateParameter("p_fecha_afiliacion_arl", adDBDate, adParamInput, , Nz(Me.txtFechaAfiliacionARL.value, Null))
        .Parameters.Append .CreateParameter("p_fecha_afiliacion_eps", adDBDate, adParamInput, , Nz(Me.txtFechaAfiliacionEPS.value, Null))
        .Parameters.Append .CreateParameter("p_fecha_afiliacion_ccf", adDBDate, adParamInput, , Nz(Me.txtFechaAfiliacionCCF.value, Null))
        .Parameters.Append .CreateParameter("p_num_ultimo_otro_si", adInteger, adParamInput, , Nz(Me.txtUltimoOtroSi.value, Null))
        .Parameters.Append .CreateParameter("p_dias_pp", adInteger, adParamInput, , Nz(Me.txtPeriodoPrueba.value, 60))
        .Parameters.Append .CreateParameter("p_contrato_vigente", adTinyInt, adParamInput, , 1)
        
        ' Parámetro para auditoría
        .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)
        
        ' Parámetro de salida para resultado
        .Parameters.Append .CreateParameter("p_resultado", adInteger, adParamOutput)
        
        ' Ejecutar y controlar errores de MySQL
        On Error Resume Next
        .Execute
        If cnn.Errors.Count > 0 Then
            MsgBox "Ocurrió un error al guardar los datos del contrato: " & cnn.Errors(0).Description, vbCritical, "Error de MySQL"
            cnn.Errors.Clear
            GoTo ExitSub
        End If
        On Error GoTo ErrHandler
        
        resultadoSP = .Parameters("p_resultado").value
    End With

    '--- 4. Procesar resultado del SP ---
    Select Case resultadoSP
        Case 1
            '--- INSERCIÓN EXITOSA ---
            ' Actualizar la tabla de control local para marcar la tarea como completada
            CurrentDb.Execute "UPDATE tbl_ingreso_actual SET contratos = True WHERE id_colaborador = '" & Me.txtid_cc.value & "';", dbFailOnError
            
            MsgBox "El contrato se ha guardado correctamente con un período de prueba de " & Nz(Me.txtPeriodoPrueba.value, 60) & " días.", vbInformation, "Proceso completado"
            
            '--- Limpieza y Refresco Final ---
            Call Limpiar_Formulario_Contrato
            Call RequeryAllDataControls(Me)
            
        Case 0
            '--- DUPLICADO: COLABORADOR YA TIENE CONTRATO VIGENTE ---
            ' Actualizar la tabla de control local aunque ya existía el registro
            CurrentDb.Execute "UPDATE tbl_ingreso_actual SET contratos = True WHERE id_colaborador = '" & Me.txtid_cc.value & "';", dbFailOnError
            
            MsgBox "Este colaborador ya tiene un contrato vigente registrado." & vbCrLf & _
                   "No se puede crear un nuevo contrato. Use el módulo de actualizaciones si desea modificarlo.", vbExclamation, "Contrato duplicado"
            
            '--- Limpieza y Refresco Final ---
            Call Limpiar_Formulario_Contrato
            Call RequeryAllDataControls(Me)
            
        Case -1
            '--- ERROR EN LA BASE DE DATOS ---
            MsgBox "Ocurrió un error en la base de datos durante la inserción.", vbCritical, "Error de MySQL"
    End Select
    
ExitSub:
    On Error Resume Next
    Set cmd = Nothing
    Exit Sub

ErrHandler:
    MsgBox "Error inesperado en el proceso de guardado: " & Err.Description, vbCritical, "Error de VBA"
    Resume ExitSub
End Sub

' Configuración al cargar el formulario
Private Sub Form_Load()
    Dim strSQL As String
    
    strSQL = "SELECT T1.id_colaborador, T1.id_cc, T1.primer_nombre, T1.segundo_nombre, T1.primer_apellido, T1.segundo_apellido " & _
             "FROM vista_colaboradores AS T1 " & _
             "INNER JOIN tbl_ingreso_actual AS T2 " & _
             "    ON T1.id_cc = T2.id_colaborador " & _
             "WHERE (T2.contratos = False);"

    Me.lstColaboradoresPendContrato.RowSource = strSQL
    Call DeshabilitarControlesContrato
End Sub

' Cargar los datos del colaborador seleccionado
Private Sub lstColaboradoresPendContrato_AfterUpdate()
    On Error GoTo ErrHandler
    
    If Me.lstColaboradoresPendContrato.ListIndex = -1 Then Exit Sub
    
    Me.txtid_colaborador = Me.lstColaboradoresPendContrato.Column(0)
    Me.txtid_cc = Me.lstColaboradoresPendContrato.Column(1)
    Me.txtPrimerNombre = Me.lstColaboradoresPendContrato.Column(2)
    Me.txtSegundoNombre = Me.lstColaboradoresPendContrato.Column(3)
    Me.txtPrimerApellido = Me.lstColaboradoresPendContrato.Column(4)
    Me.txtSegundoApellido = Me.lstColaboradoresPendContrato.Column(5)
    
    Call HabilitarControlesContrato
    
Exit Sub

ErrHandler:
    MsgBox "Error al cargar los datos del colaborador seleccionado: " & Err.Description, vbExclamation, "Error"

End Sub

' Función Deshabilitar controles
Private Sub DeshabilitarControlesContrato()
    Me.txtFechaIngreso.Enabled = False
    Me.txtFechaTerminacion.Enabled = False
    Me.txtSalarioBase.Enabled = False
    Me.txtAuxAlimentacion.Enabled = False
    Me.txtAuxTransporte.Enabled = False
    Me.txtRodamiento.Enabled = False
    Me.txtTurno.Enabled = False
    Me.txtFechaAfiliacionARL.Enabled = False
    Me.txtFechaAfiliacionEPS.Enabled = False
    Me.txtFechaAfiliacionCCF.Enabled = False
    Me.txtUltimoOtroSi.Enabled = False
    Me.txtPeriodoPrueba.Enabled = False
    
    Me.cmbCentrocosto.Enabled = False
    Me.cmbFormaPago.Enabled = False
    Me.cmbTipoContrato.Enabled = False
    
    Me.chkSalarioIntegral.Enabled = False
    Me.chkContratoOK.Enabled = False
End Sub

' Función Habilitar controles
Private Sub HabilitarControlesContrato()
    Me.txtFechaIngreso.Enabled = True
    Me.txtFechaTerminacion.Enabled = True
    Me.txtSalarioBase.Enabled = True
    Me.txtAuxAlimentacion.Enabled = True
    Me.txtAuxTransporte.Enabled = True
    Me.txtRodamiento.Enabled = True
    Me.txtTurno.Enabled = True
    Me.txtFechaAfiliacionARL.Enabled = True
    Me.txtFechaAfiliacionEPS.Enabled = True
    Me.txtFechaAfiliacionCCF.Enabled = True
    Me.txtUltimoOtroSi.Enabled = True
    Me.txtPeriodoPrueba.Enabled = True
    
    Me.cmbCentrocosto.Enabled = True
    Me.cmbFormaPago.Enabled = True
    Me.cmbTipoContrato.Enabled = True
    
    Me.chkSalarioIntegral.Enabled = True
    Me.chkContratoOK.Enabled = True
End Sub

'==================================================================================================
' FUNCIÓN PARA LIMPIAR Y REINICIAR EL FORMULARIO
'==================================================================================================
Private Sub Limpiar_Formulario_Contrato()
    Me.txtid_colaborador = Null
    Me.txtid_cc = Null
    Me.txtPrimerNombre = Null
    Me.txtSegundoNombre = Null
    Me.txtPrimerApellido = Null
    Me.txtSegundoApellido = Null
    
    Me.txtFechaIngreso = Null
    Me.txtFechaTerminacion = Null
    Me.txtSalarioBase = Null
    Me.txtAuxAlimentacion = Null
    Me.txtAuxTransporte = Null
    Me.txtRodamiento = Null
    Me.txtTurno = Null
    Me.txtFechaAfiliacionARL = Null
    Me.txtFechaAfiliacionEPS = Null
    Me.txtFechaAfiliacionCCF = Null
    Me.txtUltimoOtroSi = Null
    Me.txtPeriodoPrueba = Null
    
    Me.cmbCentrocosto = Null
    Me.cmbFormaPago = Null
    Me.cmbTipoContrato = Null
    
    Me.chkSalarioIntegral = False
    Me.chkContratoOK = False
    
    Call DeshabilitarControlesContrato
End Sub

'==================================================================================================
' --- EVENTO: txtTurno_AfterUpdate
' --- Función: Convierte el texto a mayúsculas después de que el usuario termina de escribir
'            Se aplica al control txtTurno en el formulario Registro_Contrato_Colaborador
'==================================================================================================

Private Sub txtTurno_AfterUpdate()
    ' Convertir el texto a mayúsculas solo después de actualizar
    Me.txtTurno = UCase(Me.txtTurno)
End Sub




