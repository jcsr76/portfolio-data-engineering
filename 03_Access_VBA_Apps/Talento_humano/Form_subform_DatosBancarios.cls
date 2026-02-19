VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_subform_DatosBancarios"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

'==================================================================================================
' MÓDULO DEL SUBFORMULARIO: subform_DatosBancarios
'==================================================================================================

'==================================================================================================
' --- PROCEDIMIENTO PÚBLICO: CargarDatosBancarios
' --- Función: Carga el id_colaborador en el control txtid_colaboradorDatosBancarios
'            y carga la lista de cuentas bancarias en lstColaboradoresPendBancos
'            IMPORTANTE: Limpia el listbox si id_colaborador es 0
'==================================================================================================

Public Sub CargarDatosBancarios(ByVal id_colaborador As Long)
    Dim sql As String
    
    '--- PASO 1: LIMPIAR PRIMERO ---
    Me.lstColaboradoresPendBancos.RowSource = ""
    Me.txtid_colaboradorDatosBancarios = Null
    
    '--- PASO 2: SI NO HAY COLABORADOR, SALIR ---
    If Nz(id_colaborador, 0) = 0 Then
        Exit Sub
    End If
    
    '--- PASO 3: CARGAR EL ID ---
    Me.txtid_colaboradorDatosBancarios = id_colaborador
    
    '--- PASO 4: CONSTRUIR Y EJECUTAR LA CONSULTA ---
    sql = "SELECT cuenta_id, id_colaborador, banco_id, nombre_banco, tipo_cuenta, num_cuenta, cta_contable_banco " & _
          "FROM vista_cuentas_bancarias_colaboradores " & _
          "WHERE id_colaborador = " & id_colaborador & ";"
    
    '--- PASO 5: ASIGNAR AL LISTBOX ---
    Me.lstColaboradoresPendBancos.RowSource = sql
    Me.lstColaboradoresPendBancos.Requery
    
End Sub

Private Sub BTN_Borrar_Click()
    Call LimpiarFormularioDatosBancarios
End Sub

'==================================================================================================
' --- EVENTO CLICK: BTN_EliminarDatoBancario_Click
' --- Función: Valida que hay un registro seleccionado y ejecuta la eliminación
'==================================================================================================

Private Sub BTN_EliminarDatoBancario_Click()
    On Error GoTo ErrHandler
    
    Dim cuentaId As Long
    Dim idColaborador As Long
    Dim respuesta As Integer
    
    '--- 1. Obtener el cuenta_id del control ---
    cuentaId = Nz(Me.txtCuentaId, 0)
    
    '--- 2. Validación: ¿Está seleccionado un registro? ---
    If cuentaId = 0 Then
        MsgBox "Debe seleccionar un registro de cuenta bancaria antes de continuar.", vbExclamation, "Registro no seleccionado"
        Exit Sub
    End If
    
    '--- 3. Confirmación del usuario ---
    respuesta = MsgBox("¿Está seguro de que desea eliminar este registro de cuenta bancaria?" & vbCrLf & _
                       "Esta acción no se puede deshacer.", vbQuestion + vbYesNo, "Confirmar eliminación")
    
    If respuesta <> vbYes Then
        Exit Sub
    End If
    
    '--- 4. Obtener el id_colaborador ---
    idColaborador = Nz(Me.txtid_colaboradorDatosBancarios, 0)
    
    '--- 5. Llamar al procedimiento de eliminación ---
    Call EliminarCuentaBancaria(cuentaId, idColaborador)

ExitSub:
    Exit Sub

ErrHandler:
    MsgBox "Error inesperado en el proceso: " & Err.Description, vbCritical, "Error de VBA"
    Resume ExitSub
End Sub

'==================================================================================================
' --- PROCEDIMIENTO PRIVADO: EliminarCuentaBancaria
' --- Función: Ejecuta sp_eliminar_cuenta_bancaria
'==================================================================================================

Private Sub EliminarCuentaBancaria(ByVal cuentaId As Long, ByVal idColaborador As Long)
    On Error GoTo ErrHandler
    
    Dim usuarioActual As String
    Dim cmd As ADODB.Command
    Dim resultadoSP As Integer
    
    '--- 1. Conexión a MySQL y obtención de usuario ---
    If Not VerificarYReconectarMySQL() Then Exit Sub
    usuarioActual = EstablecerUsuarioActual
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual.", vbCritical
        Exit Sub
    End If
    
    '--- 2. Establecer variable de sesión ---
    cnn.Execute "SET @usuario_actual = '" & Replace(usuarioActual, "'", "''") & "';"
    
    '--- 3. Ejecutar SP de ELIMINACIÓN ---
    Set cmd = New ADODB.Command
    With cmd
        .ActiveConnection = cnn
        .CommandType = adCmdStoredProc
        .CommandText = "sp_eliminar_cuenta_bancaria"
        
        .Parameters.Append .CreateParameter("p_cuenta_id", adInteger, adParamInput, , cuentaId)
        .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)
        .Parameters.Append .CreateParameter("p_resultado", adInteger, adParamOutput)
        
        On Error Resume Next
        .Execute
        If cnn.Errors.Count > 0 Then
            MsgBox "Error MySQL: " & cnn.Errors(0).Description, vbCritical, "Error de MySQL"
            cnn.Errors.Clear
            GoTo ExitSub
        End If
        On Error GoTo ErrHandler
        
        resultadoSP = .Parameters("p_resultado").value
    End With
    
    '--- 4. Procesar resultado ---
    Select Case resultadoSP
        Case 1
            MsgBox "La cuenta bancaria se ha eliminado correctamente.", vbInformation, "Eliminación completada"
            Call LimpiarFormularioDatosBancarios
            Call CargarDatosBancarios(idColaborador)
            Me.lstColaboradoresPendBancos.Requery
        Case -1
            MsgBox "Ocurrió un error en la base de datos durante la eliminación.", vbCritical, "Error de MySQL"
    End Select

ExitSub:
    On Error Resume Next
    Set cmd = Nothing
    Exit Sub

ErrHandler:
    MsgBox "Error en EliminarCuentaBancaria: " & Err.Description, vbCritical, "Error"
    Resume ExitSub
End Sub

'==================================================================================================
' --- EVENTO: lstColaboradoresPendBancos_Click
' --- Función: Cuando el usuario hace clic en un registro del listbox,
'            carga los datos en los controles de edición
'==================================================================================================

Private Sub lstColaboradoresPendBancos_Click()
    ' Validar que haya un registro seleccionado
    If Me.lstColaboradoresPendBancos.ListIndex = -1 Then
        Exit Sub
    End If
    
    ' Cargar los datos del registro seleccionado en los controles
    Me.txtCuentaId = Me.lstColaboradoresPendBancos.Column(0)
    Me.cmbBanco = Me.lstColaboradoresPendBancos.Column(2)
    Me.cmbTipoCuenta = Me.lstColaboradoresPendBancos.Column(4)
    Me.txtNumCuenta = Me.lstColaboradoresPendBancos.Column(5)
    Me.txtCuentaContableBanco = Me.lstColaboradoresPendBancos.Column(6)
End Sub

'==================================================================================================
' --- EVENTO: cmbBanco_AfterUpdate
' --- Función: Cuando el usuario selecciona un banco del combo,
'            carga automáticamente el campo cta_contable_banco en txtCuentaContableBanco
'==================================================================================================

Private Sub cmbBanco_AfterUpdate()
    On Error Resume Next
    
    ' Validar que haya un banco seleccionado
    If Me.cmbBanco.ListIndex = -1 Then
        Me.txtCuentaContableBanco = Null
        Exit Sub
    End If
    
    ' Cargar la cuenta contable del banco (columna 2 del combo)
    Me.txtCuentaContableBanco = Me.cmbBanco.Column(2)
    
    On Error GoTo 0
End Sub

'==================================================================================================
' --- EVENTO CLICK: BTN_GuardarDatosBancarios_Click
' --- Función: Valida datos y maneja 2 casos:
'              1. ACTUALIZAR cuenta bancaria existente (txtCuentaId lleno)
'              2. INSERTAR nueva cuenta bancaria (txtCuentaId vacío)
'==================================================================================================

Private Sub BTN_GuardarDatosBancarios_Click()
    On Error GoTo ErrHandler
    
    Dim cuentaId As Long
    Dim idColaborador As Long
    
    '--- 1. Obtener el cuenta_id del control ---
    cuentaId = Nz(Me.txtCuentaId, 0)
    
    '--- 2. Obtener el id_colaborador ---
    idColaborador = Nz(Me.txtid_colaboradorDatosBancarios, 0)
    
    '--- 3. DECISIÓN: ¿ACTUALIZAR o INSERTAR? ---
    If cuentaId > 0 Then
        '--- CASO 1: ACTUALIZAR CUENTA BANCARIA EXISTENTE ---
        Call ActualizarCuentaBancaria(cuentaId, idColaborador)
    Else
        '--- CASO 2: INSERTAR NUEVA CUENTA BANCARIA ---
        Call InsertarCuentaBancaria(idColaborador)
    End If

ExitSub:
    Exit Sub

ErrHandler:
    MsgBox "Error inesperado en el proceso: " & Err.Description, vbCritical, "Error de VBA"
    Resume ExitSub
End Sub

'==================================================================================================
' --- PROCEDIMIENTO PRIVADO: ActualizarCuentaBancaria
' --- Función: Ejecuta sp_actualizar_cuenta_bancaria
'==================================================================================================

Private Sub ActualizarCuentaBancaria(ByVal cuentaId As Long, ByVal idColaborador As Long)
    On Error GoTo ErrHandler
    
    Dim usuarioActual As String
    Dim cmd As ADODB.Command
    Dim resultadoSP As Integer
    Dim bancoId As Integer
    Dim tipoCuenta As String
    Dim numCuenta As String
    Dim cuentaContableBanco As String
    
    '--- 1. Validación: ¿Están completos los datos? ---
    bancoId = Nz(Me.cmbBanco, 0)
    tipoCuenta = Nz(Me.cmbTipoCuenta, "")
    numCuenta = Nz(Me.txtNumCuenta, "")
    cuentaContableBanco = Nz(Me.txtCuentaContableBanco, "")
    
    If bancoId = 0 Or tipoCuenta = "" Or numCuenta = "" Or cuentaContableBanco = "" Then
        MsgBox "Debe completar todos los campos obligatorios.", vbExclamation, "Campos incompletos"
        Exit Sub
    End If
    
    '--- 2. Conexión a MySQL y obtención de usuario ---
    If Not VerificarYReconectarMySQL() Then Exit Sub
    usuarioActual = EstablecerUsuarioActual
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual.", vbCritical
        Exit Sub
    End If
    
    '--- 3. Establecer variable de sesión ---
    cnn.Execute "SET @usuario_actual = '" & Replace(usuarioActual, "'", "''") & "';"
    
    '--- 4. Ejecutar SP de ACTUALIZACIÓN ---
    Set cmd = New ADODB.Command
    With cmd
        .ActiveConnection = cnn
        .CommandType = adCmdStoredProc
        .CommandText = "sp_actualizar_cuenta_bancaria"
        
        .Parameters.Append .CreateParameter("p_cuenta_id", adInteger, adParamInput, , cuentaId)
        .Parameters.Append .CreateParameter("p_banco_id", adInteger, adParamInput, , bancoId)
        .Parameters.Append .CreateParameter("p_tipo_cuenta", adVarChar, adParamInput, 20, tipoCuenta)
        .Parameters.Append .CreateParameter("p_num_cuenta", adVarChar, adParamInput, 100, numCuenta)
        .Parameters.Append .CreateParameter("p_cta_contable_banco", adVarChar, adParamInput, 50, cuentaContableBanco)
        .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)
        .Parameters.Append .CreateParameter("p_filas_afectadas", adInteger, adParamOutput)
        
        On Error Resume Next
        .Execute
        If cnn.Errors.Count > 0 Then
            MsgBox "Error MySQL: " & cnn.Errors(0).Description, vbCritical, "Error de MySQL"
            cnn.Errors.Clear
            GoTo ExitSub
        End If
        On Error GoTo ErrHandler
        
        resultadoSP = .Parameters("p_filas_afectadas").value
    End With
    
    '--- 5. Procesar resultado ---
    Select Case resultadoSP
        Case 1
            MsgBox "La cuenta bancaria se ha actualizado correctamente.", vbInformation, "Actualización completada"
            Call LimpiarFormularioDatosBancarios
            Call CargarDatosBancarios(idColaborador)
        Case 0
            MsgBox "No se detectaron cambios en los datos.", vbInformation, "Sin cambios"
        Case -1
            MsgBox "Error en la base de datos.", vbCritical, "Error"
    End Select

ExitSub:
    On Error Resume Next
    Set cmd = Nothing
    Exit Sub

ErrHandler:
    MsgBox "Error en ActualizarCuentaBancaria: " & Err.Description, vbCritical, "Error"
    Resume ExitSub
End Sub

'==================================================================================================
' --- PROCEDIMIENTO PRIVADO: InsertarCuentaBancaria
' --- Función: Ejecuta sp_insertar_cuenta_bancaria
'==================================================================================================

Private Sub InsertarCuentaBancaria(ByVal idColaborador As Long)
    On Error GoTo ErrHandler
    
    Dim usuarioActual As String
    Dim cmd As ADODB.Command
    Dim bancoId As Integer
    Dim tipoCuenta As String
    Dim numCuenta As String
    Dim cuentaContableBanco As String
    Dim resultadoSP As Integer
    
    '--- 1. Validación: ¿El usuario ha seleccionado un colaborador? ---
    If idColaborador = 0 Then
        MsgBox "Debe seleccionar un colaborador de la lista principal.", vbExclamation, "Colaborador no seleccionado"
        Exit Sub
    End If
    
    '--- 2. Validación: ¿Están completos los datos? ---
    bancoId = Nz(Me.cmbBanco, 0)
    tipoCuenta = Nz(Me.cmbTipoCuenta, "")
    numCuenta = Nz(Me.txtNumCuenta, "")
    cuentaContableBanco = Nz(Me.txtCuentaContableBanco, "")
    
    If bancoId = 0 Or tipoCuenta = "" Or numCuenta = "" Or cuentaContableBanco = "" Then
        MsgBox "Debe completar todos los campos obligatorios:" & vbCrLf & _
               "- Banco" & vbCrLf & _
               "- Tipo de Cuenta" & vbCrLf & _
               "- Número de Cuenta" & vbCrLf & _
               "- Cuenta Contable", vbExclamation, "Campos incompletos"
        Exit Sub
    End If
    
    '--- 3. Conexión a MySQL y obtención de usuario ---
    If Not VerificarYReconectarMySQL() Then Exit Sub
    usuarioActual = EstablecerUsuarioActual
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual.", vbCritical
        Exit Sub
    End If
    
    '--- 4. Establecer variable de sesión ---
    cnn.Execute "SET @usuario_actual = '" & Replace(usuarioActual, "'", "''") & "';"
    
    '--- 5. Ejecutar SP de INSERCIÓN ---
    Set cmd = New ADODB.Command
    With cmd
        .ActiveConnection = cnn
        .CommandType = adCmdStoredProc
        .CommandText = "sp_insertar_cuenta_bancaria"
        
        .Parameters.Append .CreateParameter("p_id_colaborador", adInteger, adParamInput, , idColaborador)
        .Parameters.Append .CreateParameter("p_banco_id", adInteger, adParamInput, , bancoId)
        .Parameters.Append .CreateParameter("p_tipo_cuenta", adVarChar, adParamInput, 20, tipoCuenta)
        .Parameters.Append .CreateParameter("p_num_cuenta", adVarChar, adParamInput, 100, numCuenta)
        .Parameters.Append .CreateParameter("p_cta_contable_banco", adVarChar, adParamInput, 50, cuentaContableBanco)
        .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)
        .Parameters.Append .CreateParameter("p_resultado", adInteger, adParamOutput)
        
        On Error Resume Next
        .Execute
        If cnn.Errors.Count > 0 Then
            MsgBox "Error MySQL: " & cnn.Errors(0).Description, vbCritical, "Error de MySQL"
            cnn.Errors.Clear
            GoTo ExitSub
        End If
        On Error GoTo ErrHandler
        
        resultadoSP = .Parameters("p_resultado").value
    End With
    
    '--- 6. Procesar resultado ---
    Select Case resultadoSP
        Case 1
            MsgBox "La nueva cuenta bancaria se ha registrado correctamente.", vbInformation, "Inserción completada"
            Call LimpiarFormularioDatosBancarios
            Call CargarDatosBancarios(idColaborador)
        Case 0
            MsgBox "Este colaborador ya tiene una cuenta bancaria registrada." & vbCrLf & _
                   "Use el módulo de actualizaciones si desea modificarla.", vbExclamation, "Cuenta duplicada"
        Case -1
            MsgBox "Ocurrió un error en la base de datos durante la inserción.", vbCritical, "Error de MySQL"
    End Select

ExitSub:
    On Error Resume Next
    Set cmd = Nothing
    Exit Sub

ErrHandler:
    MsgBox "Error en InsertarCuentaBancaria: " & Err.Description, vbCritical, "Error"
    Resume ExitSub
End Sub

'==================================================================================================
' --- PROCEDIMIENTO PRIVADO: LimpiarFormularioDatosBancarios
' --- Función: Limpia todos los controles de edición de datos bancarios a su estado inicial
'==================================================================================================

Private Sub LimpiarFormularioDatosBancarios()
    On Error Resume Next
    
    ' Limpiar los controles de edición de datos bancarios
    Me.txtCuentaId = Null
    Me.cmbBanco = Null
    Me.cmbTipoCuenta = Null
    Me.txtNumCuenta = Null
    Me.txtCuentaContableBanco = Null
    
    On Error GoTo 0
End Sub

