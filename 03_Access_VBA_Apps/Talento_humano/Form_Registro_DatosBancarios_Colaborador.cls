VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Registro_DatosBancarios_Colaborador"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

' Botón Borrar
Private Sub BTN_Borrar_Click()
    Call Limpiar_Formulario_Bancos
End Sub

' configuración al cargar el formulario
Private Sub Form_Load()
    Dim strSQL As String
    
    ' Carga de datos de colaboradores ingresados a MySQL que no tienen registrados
    ' datos de contacto y datos de segurdad social
    ' 1. Definimos la consulta SQL
    ' Unimos la vista de MySQL (T1) con la tabla local (T2)
    ' usando el campo de cédula (id_cc) y el campo de texto (id_colaborador).
    strSQL = "SELECT T1.id_colaborador, T1.id_cc, T1.primer_nombre, T1.segundo_nombre, T1.primer_apellido, T1.segundo_apellido " & _
             "FROM vista_colaboradores AS T1 " & _
             "INNER JOIN tbl_ingreso_actual AS T2 " & _
             "    ON T1.id_cc = T2.id_colaborador " & _
             "WHERE (T2.cuentas_bancarias_colaboradores = False);"

    ' 2. Asignamos la consulta al Origen de la Fila del ListBox
    Me.lstColaboradoresPendBancos.RowSource = strSQL
    
    ' Deshabilitar controles al inicio
     Call DesHabilitarControlesBancos
    
End Sub

' Cargar los datos del colaborador seleccionado
Private Sub lstColaboradoresPendBancos_AfterUpdate()
    On Error GoTo ErrHandler
    
    ' Asegurarse de que haya una selección
    If Me.lstColaboradoresPendBancos.ListIndex = -1 Then Exit Sub
    
    ' Asignar los valores de las columnas del ListBox a los controles del formulario
    Me.txtid_colaborador = Me.lstColaboradoresPendBancos.Column(0)   ' T1.id_colaborador
    Me.txtid_cc = Me.lstColaboradoresPendBancos.Column(1)            ' T1.id_cc
    Me.txtPrimerNombre = Me.lstColaboradoresPendBancos.Column(2)     ' T1.primer_nombre
    Me.txtSegundoNombre = Me.lstColaboradoresPendBancos.Column(3)    ' T1.segundo_nombre
    Me.txtPrimerApellido = Me.lstColaboradoresPendBancos.Column(4)   ' T1.primer_apellido
    Me.txtSegundoApellido = Me.lstColaboradoresPendBancos.Column(5)  ' T1.segundo_apellido
    
    ' Habilitar controles de contacto y afiliaciones
    Call HabilitarControlesBancos
    
Exit Sub

ErrHandler:
    MsgBox "Error al cargar los datos del colaborador seleccionado: " & Err.Description, vbExclamation, "Error"

End Sub
'==================================================================================================
' EVENTO CLICK DEL BOTÓN GUARDAR (Para el formulario de Datos Bancarios)
' Valida, conecta, llama al SP, actualiza la tabla local y limpia el formulario.
'==================================================================================================
Private Sub BTN_Guardar_Click()
    On Error GoTo ErrHandler
    
    Dim cmd As ADODB.Command
    Dim usuarioActual As String
    Dim resultadoSP As Integer

    '--- 1. Validación de campos obligatorios ---
    If Nz(Me.txtid_colaborador, 0) = 0 Then
        MsgBox "Debe seleccionar un colaborador de la lista antes de continuar.", vbExclamation, "Faltan datos"
        Exit Sub
    End If
    If IsNull(Me.cmbBanco) Then
        MsgBox "Debe seleccionar un Banco de la lista.", vbExclamation, "Dato Requerido"
        Me.cmbBanco.SetFocus
        Exit Sub
    End If
    If IsNull(Me.cmbTipoCuenta) Then
        MsgBox "Debe seleccionar un Tipo de Cuenta de la lista.", vbExclamation, "Dato Requerido"
        Me.cmbTipoCuenta.SetFocus
        Exit Sub
    End If
    If Trim(Nz(Me.txtNumCuenta.value, "")) = "" Then
        MsgBox "El campo 'Número de Cuenta' es obligatorio.", vbExclamation, "Dato Requerido"
        Me.txtNumCuenta.SetFocus
        Exit Sub
    End If
    If Trim(Nz(Me.txtCuentaContableBanco.value, "")) = "" Then
        MsgBox "El campo 'Cuenta Contable' es obligatorio.", vbExclamation, "Dato Requerido"
        Me.txtCuentaContableBanco.SetFocus
        Exit Sub
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
        .CommandText = "sp_insertar_cuenta_bancaria"
        
        ' Asignación de parámetros
        .Parameters.Append .CreateParameter("p_id_colaborador", adInteger, adParamInput, , Me.txtid_colaborador.value)
        .Parameters.Append .CreateParameter("p_banco_id", adInteger, adParamInput, , Me.cmbBanco.value)
        .Parameters.Append .CreateParameter("p_tipo_cuenta", adVarChar, adParamInput, 20, Me.cmbTipoCuenta.value)
        .Parameters.Append .CreateParameter("p_num_cuenta", adVarChar, adParamInput, 100, Me.txtNumCuenta.value)
        .Parameters.Append .CreateParameter("p_cta_contable_banco", adVarChar, adParamInput, 50, Me.txtCuentaContableBanco.value)
        .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)
        .Parameters.Append .CreateParameter("p_resultado", adInteger, adParamOutput)
        
        On Error Resume Next
        .Execute
        If cnn.Errors.Count > 0 Then
            MsgBox "Ocurrió un error al guardar los datos bancarios: " & cnn.Errors(0).Description, vbCritical, "Error de MySQL"
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
            ' Actualizar la tabla de control local para marcar la tarea como completada.
            CurrentDb.Execute "UPDATE tbl_ingreso_actual SET cuentas_bancarias_colaboradores = True WHERE id_colaborador = '" & Me.txtid_cc.value & "';", dbFailOnError
            
            MsgBox "Los datos bancarios se han guardado correctamente.", vbInformation, "Proceso completado"
            
            '--- Limpieza y Refresco Final ---
            Call Limpiar_Formulario_Bancos
            Me.lstColaboradoresPendBancos.Requery
            
        Case 0
            '--- DUPLICADO: EL COLABORADOR YA TIENE CUENTA ---
            ' Actualizar la tabla de control local aunque ya existía el registro
            CurrentDb.Execute "UPDATE tbl_ingreso_actual SET cuentas_bancarias_colaboradores = True WHERE id_colaborador = '" & Me.txtid_cc.value & "';", dbFailOnError
            
            MsgBox "Este colaborador ya tiene una cuenta bancaria registrada." & vbCrLf & _
                   "Use el módulo de actualizaciones si desea modificarla.", vbExclamation, "Cuenta duplicada"
            
            '--- Limpieza y Refresco Final ---
            Call Limpiar_Formulario_Bancos
            Me.lstColaboradoresPendBancos.Requery
            
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

' función Deshabilitar controles
Private Sub DesHabilitarControlesBancos()

    Me.txtNumCuenta.Enabled = False
    Me.txtCuentaContableBanco.Enabled = False

    Me.cmbBanco.Enabled = False
    Me.cmbTipoCuenta.Enabled = False
    
End Sub

' función Habilitar controles
Private Sub HabilitarControlesBancos()

    Me.txtNumCuenta.Enabled = True
    Me.txtCuentaContableBanco.Enabled = True
    
    Me.cmbBanco.Enabled = True
    Me.cmbTipoCuenta.Enabled = True
    
End Sub

'==================================================================================================
' FUNCIÓN PARA LIMPIAR Y REINICIAR EL FORMULARIO
' Limpia todos los controles de ingreso de datos y los deshabilita.
'==================================================================================================
Private Sub Limpiar_Formulario_Bancos()
    ' --- Limpiar campos de identificación del colaborador ---
    Me.txtid_colaborador = Null
    Me.txtid_cc = Null
    Me.txtPrimerNombre = Null
    Me.txtSegundoNombre = Null
    Me.txtPrimerApellido = Null
    Me.txtSegundoApellido = Null
    
    ' --- Limpiar campos de datos del contrato (Fechas y Textos) ---
    Me.txtNumCuenta = Null
    Me.txtCuentaContableBanco = Null

    
    ' --- Limpiar Cuadros Combinados (ComboBox) ---
    Me.cmbBanco = Null
    Me.cmbTipoCuenta = Null
    
    
    ' --- Finalmente, deshabilitar todos los controles ---
    Call DesHabilitarControlesBancos
End Sub

'==================================================================================================
' EVENTO AL ACTUALIZAR EL COMBOBOX DE BANCO
' Actualiza el campo de texto de la cuenta contable con el valor de la columna 3 del combo.
'==================================================================================================
Private Sub cmbBanco_AfterUpdate()
    On Error GoTo ErrHandler
    
    ' Asegurarse de que haya una selección válida
    If Me.cmbBanco.ListIndex = -1 Then
        Me.txtCuentaContableBanco.value = Null
        Exit Sub
    End If
    
    ' La propiedad .Column es de base 0, por lo que la tercera columna es .Column(2).
    ' Asigna el valor de la tercera columna (cta_contable_banco) al TextBox.
    Me.txtCuentaContableBanco.value = Me.cmbBanco.Column(2)
    
Exit Sub

ErrHandler:
    Me.txtCuentaContableBanco.value = "Error"
    MsgBox "Error al actualizar la cuenta contable: " & Err.Description, vbExclamation, "Error"
End Sub


