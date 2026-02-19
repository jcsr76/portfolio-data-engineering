VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_subform_BeneficiariosColaborador"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

'==================================================================================================
' MÓDULO DEL SUBFORMULARIO: subform_BeneficiariosColaborador
'==================================================================================================

'==================================================================================================
' --- PROCEDIMIENTO: CargarDatosBeneficiarios (VERSIÓN CORREGIDA)
' --- Función: Carga el id_colaborador en el control txtid_colaboradorBeneficiarios
'            y carga la lista de beneficiarios en lstBeneficiariosColaboradores
'            IMPORTANTE: Limpia el listbox si id_colaborador es 0
'==================================================================================================

Public Sub CargarDatosBeneficiarios(ByVal id_colaborador As Long)
    Dim sql As String
    
    '--- PASO 1: LIMPIAR PRIMERO ---
    Me.lstBeneficiariosColaboradores.RowSource = ""
    Me.txtid_colaboradorBeneficiarios = Null
    Me.txt_idBeneficiarioColoaborador = Null
    Me.txtNombreBeneficiarioEditar = Null
    Me.cmbGeneroBeneficiarioColaborador = Null
    Me.txtFechaNacimientoBeneficiarioEditar = Null
    
    '--- PASO 2: SI NO HAY COLABORADOR, SALIR ---
    If Nz(id_colaborador, 0) = 0 Then
        Exit Sub
    End If
    
    '--- PASO 3: CARGAR EL ID ---
    Me.txtid_colaboradorBeneficiarios = id_colaborador
    
    '--- PASO 4: CONSTRUIR Y EJECUTAR LA CONSULTA ---
    sql = "SELECT id_beneficiario, id_colaborador, nombre, genero, fecha_nacimiento, edad " & _
          "FROM vista_beneficiarios " & _
          "WHERE id_colaborador = " & id_colaborador & ";"

    
    '--- PASO 5: ASIGNAR AL LISTBOX ---
    Me.lstBeneficiariosColaboradores.RowSource = sql
    Me.lstBeneficiariosColaboradores.Requery
End Sub

'==================================================================================================
' --- PROCEDIMIENTO PRIVADO: LimpiarFormularioBeneficiarios
' --- Función: Limpia todos los controles del formulario a su estado inicial
'==================================================================================================

Private Sub LimpiarFormularioBeneficiarios()
    On Error Resume Next
    
    ' Limpiar control de ID del colaborador
    Me.txtid_colaboradorBeneficiarios = Null
    
    ' Limpiar el listbox
    Me.lstBeneficiariosColaboradores.RowSource = ""
    
    ' Limpiar los controles de edición de beneficiarios
    Me.txt_idBeneficiarioColoaborador = Null
    Me.txtNombreBeneficiarioEditar = Null
    Me.cmbGeneroBeneficiarioColaborador = Null
    Me.txtFechaNacimientoBeneficiarioEditar = Null
    
    On Error GoTo 0
End Sub

'==================================================================================================
' --- EVENTO: lstBeneficiariosColaboradores_Click
' --- Función: Cuando el usuario hace clic en un registro del listbox,
'            carga los datos en los controles de edición
'==================================================================================================

Private Sub lstBeneficiariosColaboradores_Click()
    ' Validar que haya un registro seleccionado
    If Me.lstBeneficiariosColaboradores.ListIndex = -1 Then
        Exit Sub
    End If
    
    ' Cargar los datos del registro seleccionado en los controles
    Me.txt_idBeneficiarioColoaborador = Me.lstBeneficiariosColaboradores.Column(0)
    Me.txtNombreBeneficiarioEditar = Me.lstBeneficiariosColaboradores.Column(2)
    Me.cmbGeneroBeneficiarioColaborador = Me.lstBeneficiariosColaboradores.Column(3)
    Me.txtFechaNacimientoBeneficiarioEditar = Me.lstBeneficiariosColaboradores.Column(4)
End Sub

'==================================================================================================
' --- FUNCIÓN: GenerarJSONBeneficiarios
' --- Función: Genera un JSON a partir de los datos en tbl_beneficiarios_temporal
'==================================================================================================

Private Function GenerarJSONBeneficiarios(frmTemporal As Object) As String
    On Error GoTo ErrHandler
    
    Dim rs As ADODB.Recordset
    Dim jsonArray As String
    Dim nombreBeneficiario As String
    Dim generoBeneficiario As String
    Dim fechaNacimientoBeneficiario As String
    Dim contador As Integer
    
    jsonArray = "["
    contador = 0
    
    ' Abrir la tabla temporal
    Set rs = New ADODB.Recordset
    rs.Open "SELECT nombre, genero, fecha_nacimiento FROM tbl_beneficiarios_temporal ORDER BY nombre;", CurrentProject.Connection, adOpenKeyset, adLockReadOnly
    
    ' Iterar sobre los registros
    While Not rs.EOF
        nombreBeneficiario = Nz(rs!nombre, "")
        generoBeneficiario = Nz(rs!genero, "")
        fechaNacimientoBeneficiario = Nz(Format(rs!fecha_nacimiento, "yyyy-mm-dd"), "")
        
        ' Validar que al menos el nombre esté presente
        If nombreBeneficiario <> "" Then
            ' Agregar coma si no es el primer registro
            If contador > 0 Then jsonArray = jsonArray & ","
            
            ' Construir el objeto JSON
            jsonArray = jsonArray & "{" & _
                        """nombre"":""" & Replace(nombreBeneficiario, """", "\""") & """," & _
                        """genero"":""" & generoBeneficiario & """," & _
                        """fecha_nacimiento"":""" & fechaNacimientoBeneficiario & """" & _
                        "}"
            
            contador = contador + 1
        End If
        
        rs.MoveNext
    Wend
    
    jsonArray = jsonArray & "]"
    
    rs.Close
    Set rs = Nothing
    
    ' Retornar el JSON generado
    GenerarJSONBeneficiarios = jsonArray
    Exit Function

ErrHandler:
    GenerarJSONBeneficiarios = "ERROR"
End Function

'==================================================================================================
' --- EVENTO CLICK: BTN_GuardarBeneficiarioColaborador_Click
' --- Función: Valida datos y maneja 3 casos:
'              1. Solo INSERTAR nuevos beneficiarios (tabla temporal llena, sin id_beneficiario)
'              2. Solo ACTUALIZAR beneficiario existente (id_beneficiario lleno, tabla temporal vacía)
'              3. AMBAS cosas (tabla temporal llena + id_beneficiario lleno)
'==================================================================================================

Private Sub BTN_GuardarBeneficiarioColaborador_Click()
    On Error GoTo ErrHandler
    
    Dim usuarioActual As String
    Dim jsonBeneficiarios As String
    Dim cmd As ADODB.Command
    Dim idColaborador As Long
    Dim idBeneficiario As Long
    Dim conteoTempora As Long
    Dim resultadoSP As Integer
    
    '--- 1. Validación inicial: Asegurarse de que hay un colaborador seleccionado ---
    idColaborador = Nz(Me.txtid_colaboradorBeneficiarios, 0)
    If idColaborador = 0 Then
        MsgBox "Debe seleccionar un colaborador de la lista antes de continuar.", vbExclamation, "Faltan datos"
        Exit Sub
    End If
    
    '--- 2. Obtener el conteo de registros en la tabla temporal ---
    conteoTempora = DCount("*", "tbl_beneficiarios_temporal")
    
    '--- 3. Obtener el id_beneficiario si existe ---
    idBeneficiario = Nz(Me.txt_idBeneficiarioColoaborador, 0)
    
    '--- 4. Validación: ¿Hay algo que hacer? ---
    If conteoTempora = 0 And idBeneficiario = 0 Then
        MsgBox "Debe ingresar beneficiarios en la tabla temporal o seleccionar un beneficiario para editar.", vbExclamation, "Faltan datos"
        Exit Sub
    End If
    
    '--- 5. Conexión a MySQL y obtención de usuario ---
    If Not VerificarYReconectarMySQL() Then Exit Sub
    usuarioActual = EstablecerUsuarioActual
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual. No es posible continuar.", vbCritical
        Exit Sub
    End If
    
    '--- 6. Establecer la variable de sesión para auditoría ---
    cnn.Execute "SET @usuario_actual = '" & Replace(usuarioActual, "'", "''") & "';"
    
    '--- 7. CASO 1 y 3: ¿Hay datos en la tabla temporal? INSERTAR NUEVOS BENEFICIARIOS ---
    If conteoTempora > 0 Then
        jsonBeneficiarios = GenerarJSONBeneficiarios(Me.frm_tbl_beneficiarios_temporal.Form)
        If jsonBeneficiarios = "ERROR" Or jsonBeneficiarios = "[]" Then
            MsgBox "No se pudieron procesar los datos de los beneficiarios. Por favor, revise la tabla.", vbCritical, "Error de Datos"
            Exit Sub
        End If
        
        ' Configurar y Ejecutar el Procedimiento Almacenado de INSERCIÓN (SP NUEVO)
        Set cmd = New ADODB.Command
        With cmd
            .ActiveConnection = cnn
            .CommandType = adCmdStoredProc
            .CommandText = "sp_insertar_beneficiarios_adicionales"
            
            .Parameters.Append .CreateParameter("p_id_colaborador", adInteger, adParamInput, , idColaborador)
            .Parameters.Append .CreateParameter("p_beneficiarios_json", adLongVarChar, adParamInput, Len(jsonBeneficiarios), jsonBeneficiarios)
            .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)
            .Parameters.Append .CreateParameter("p_resultado", adInteger, adParamOutput)
            
            On Error Resume Next
            .Execute
            If cnn.Errors.Count > 0 Then
                MsgBox "Ocurrió un error al insertar los beneficiarios: " & cnn.Errors(0).Description, vbCritical, "Error de MySQL"
                cnn.Errors.Clear
                GoTo ExitSub
            End If
            On Error GoTo ErrHandler
            
            resultadoSP = .Parameters("p_resultado").value
        End With
        
        ' Procesar resultado de la inserción
        Select Case resultadoSP
            Case 1
                '--- ÉXITO: Beneficiarios insertados (sin restricción de duplicados) ---
                Me.frm_tbl_beneficiarios_temporal.SourceObject = ""
                CurrentDb.Execute "DELETE FROM tbl_beneficiarios_temporal;", dbFailOnError
                Me.frm_tbl_beneficiarios_temporal.SourceObject = "frm_tbl_beneficiarios_temporal"
                
                MsgBox "Los nuevos beneficiarios se han insertado correctamente.", vbInformation, "Inserción completada"
                
            Case -1
                '--- ERROR SQL ---
                Me.frm_tbl_beneficiarios_temporal.SourceObject = ""
                CurrentDb.Execute "DELETE FROM tbl_beneficiarios_temporal;", dbFailOnError
                Me.frm_tbl_beneficiarios_temporal.SourceObject = "frm_tbl_beneficiarios_temporal"
                
                MsgBox "Ocurrió un error en la base de datos durante la inserción.", vbCritical, "Error de MySQL"
                Me.frm_tbl_beneficiarios_temporal.Requery
        End Select
    End If
    
    '--- 8. CASO 2 y 3: ¿Hay id_beneficiario? ACTUALIZAR BENEFICIARIO EXISTENTE ---
    If idBeneficiario > 0 Then
        ' Configurar y Ejecutar el Procedimiento Almacenado de ACTUALIZACIÓN
        Set cmd = New ADODB.Command
        With cmd
            .ActiveConnection = cnn
            .CommandType = adCmdStoredProc
            .CommandText = "sp_actualizar_beneficiario"
            
            .Parameters.Append .CreateParameter("p_id_beneficiario", adInteger, adParamInput, , idBeneficiario)
            .Parameters.Append .CreateParameter("p_nombre", adVarChar, adParamInput, 100, Nz(Me.txtNombreBeneficiarioEditar, ""))
            .Parameters.Append .CreateParameter("p_genero", adVarChar, adParamInput, 10, Nz(Me.cmbGeneroBeneficiarioColaborador, ""))
            .Parameters.Append .CreateParameter("p_fecha_nacimiento", adVarChar, adParamInput, 10, Format(Nz(Me.txtFechaNacimientoBeneficiarioEditar, ""), "yyyy-mm-dd"))
            .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)
            .Parameters.Append .CreateParameter("p_filas_afectadas", adInteger, adParamOutput)
            
            On Error Resume Next
            .Execute
            If cnn.Errors.Count > 0 Then
                MsgBox "Ocurrió un error al actualizar el beneficiario: " & cnn.Errors(0).Description, vbCritical, "Error de MySQL"
                cnn.Errors.Clear
                GoTo ExitSub
            End If
            On Error GoTo ErrHandler
            
            resultadoSP = .Parameters("p_filas_afectadas").value
        End With
        
        ' Procesar resultado de la actualización
        Select Case resultadoSP
            Case 1
                MsgBox "El beneficiario se ha actualizado correctamente.", vbInformation, "Actualización completada"
            Case 0
                MsgBox "No se detectaron cambios en los datos del beneficiario. No se realizó ninguna actualización.", vbInformation, "Sin cambios"
            Case -1
                MsgBox "Ocurrió un error en la base de datos durante la actualización.", vbCritical, "Error de MySQL"
                GoTo ExitSub
        End Select
        
        ' Limpiar los controles de edición
        Me.txt_idBeneficiarioColoaborador = Null
        Me.txtNombreBeneficiarioEditar = Null
        Me.cmbGeneroBeneficiarioColaborador = Null
        Me.txtFechaNacimientoBeneficiarioEditar = Null
    End If
    
    '--- 9. Recargar la lista de beneficiarios ---
    Call CargarDatosBeneficiarios(idColaborador)

ExitSub:
    On Error Resume Next
    Set cmd = Nothing
    Exit Sub

ErrHandler:
    MsgBox "Error inesperado en el proceso: " & Err.Description, vbCritical, "Error de VBA"
    Resume ExitSub
End Sub

'==================================================================================================
' --- EVENTO CLICK: BTN_EliminarBeneficiario_Click
' --- Función: Elimina un beneficiario existente basado en el id_beneficiario
'            Valida que el usuario haya seleccionado un beneficiario antes de eliminar
'            Solicita confirmación al usuario antes de ejecutar la eliminación
'==================================================================================================

Private Sub BTN_EliminarBeneficiario_Click()
    On Error GoTo ErrHandler
    
    Dim usuarioActual As String
    Dim cmd As ADODB.Command
    Dim idBeneficiario As Long
    Dim idColaborador As Long
    Dim resultadoSP As Integer
    Dim respuestaUsuario As VbMsgBoxResult
    
    '--- 1. Obtener el id_beneficiario del control ---
    idBeneficiario = Nz(Me.txt_idBeneficiarioColoaborador, 0)
    idColaborador = Nz(Me.txtid_colaboradorBeneficiarios, 0)
    
    '--- 2. Validación: ¿El usuario ha seleccionado un beneficiario? ---
    If idBeneficiario = 0 Then
        MsgBox "Debe seleccionar un beneficiario del listado para eliminar.", vbExclamation, "Beneficiario no seleccionado"
        Exit Sub
    End If
    
    '--- 3. Solicitar confirmación al usuario ---
    respuestaUsuario = MsgBox("¿Está seguro de que desea eliminar este beneficiario?" & vbCrLf & vbCrLf & _
                               "Nombre: " & Nz(Me.txtNombreBeneficiarioEditar, "N/A") & vbCrLf & vbCrLf & _
                               "Esta acción no se puede deshacer.", vbQuestion + vbYesNo, "Confirmar eliminación")
    
    If respuestaUsuario <> vbYes Then
        Exit Sub
    End If
    
    '--- 4. Conexión a MySQL y obtención de usuario ---
    If Not VerificarYReconectarMySQL() Then Exit Sub
    usuarioActual = EstablecerUsuarioActual
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual. No es posible continuar.", vbCritical
        Exit Sub
    End If
    
    '--- 5. Establecer la variable de sesión para auditoría ---
    cnn.Execute "SET @usuario_actual = '" & Replace(usuarioActual, "'", "''") & "';"
    
    '--- 6. Configurar y Ejecutar el Procedimiento Almacenado de ELIMINACIÓN ---
    Set cmd = New ADODB.Command
    With cmd
        .ActiveConnection = cnn
        .CommandType = adCmdStoredProc
        .CommandText = "sp_eliminar_beneficiario"
        
        .Parameters.Append .CreateParameter("p_id_beneficiario", adInteger, adParamInput, , idBeneficiario)
        .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)
        .Parameters.Append .CreateParameter("p_resultado", adInteger, adParamOutput)
        
        On Error Resume Next
        .Execute
        If cnn.Errors.Count > 0 Then
            MsgBox "Ocurrió un error al eliminar el beneficiario: " & cnn.Errors(0).Description, vbCritical, "Error de MySQL"
            cnn.Errors.Clear
            GoTo ExitSub
        End If
        On Error GoTo ErrHandler
        
        resultadoSP = .Parameters("p_resultado").value
    End With
    
    '--- 7. Procesar resultado de la eliminación ---
    If resultadoSP = 1 Then
        MsgBox "El beneficiario se ha eliminado correctamente.", vbInformation, "Eliminación completada"
        
        ' Limpiar los controles de edición
        Me.txt_idBeneficiarioColoaborador = Null
        Me.txtNombreBeneficiarioEditar = Null
        Me.cmbGeneroBeneficiarioColaborador = Null
        Me.txtFechaNacimientoBeneficiarioEditar = Null
        
        ' Recargar la lista de beneficiarios
        Call CargarDatosBeneficiarios(idColaborador)
    ElseIf resultadoSP = -1 Then
        MsgBox "Ocurrió un error en la base de datos durante la eliminación.", vbCritical, "Error de MySQL"
        GoTo ExitSub
    End If

ExitSub:
    On Error Resume Next
    Set cmd = Nothing
    Exit Sub

ErrHandler:
    MsgBox "Error inesperado en el proceso de eliminación: " & Err.Description, vbCritical, "Error de VBA"
    Resume ExitSub
End Sub

'==================================================================================================
' --- EVENTO CLICK: BTN_BorrarFormBeneficiario_Click
' --- Función: Limpia todos los controles de edición y borra la tabla temporal
'            Mantiene: txtid_colaboradorBeneficiarios y lstBeneficiariosColaboradores
'            Recarga el listbox y el subformulario temporal
'==================================================================================================

Private Sub BTN_BorrarFormBeneficiario_Click()
    On Error GoTo ErrHandler
    
    Dim idColaborador As Long
    
    '--- 1. Obtener el id_colaborador antes de limpiar ---
    idColaborador = Nz(Me.txtid_colaboradorBeneficiarios, 0)
    
    '--- 2. Limpiar la tabla temporal ---
    CurrentDb.Execute "DELETE FROM tbl_beneficiarios_temporal;", dbFailOnError
    
    '--- 3. Hacer Requery del subformulario temporal para limpiar la vista ---
    Me.frm_tbl_beneficiarios_temporal.Form.Requery
    
    '--- 4. Limpiar los controles de edición ---
    Me.txt_idBeneficiarioColoaborador = Null
    Me.txtNombreBeneficiarioEditar = Null
    Me.cmbGeneroBeneficiarioColaborador = Null
    Me.txtFechaNacimientoBeneficiarioEditar = Null
    
    '--- 5. Recargar el listbox de beneficiarios ---
    If idColaborador > 0 Then
        Call CargarDatosBeneficiarios(idColaborador)
    End If
    
    MsgBox "Se ha limpiado el formulario correctamente.", vbInformation, "Formulario limpiado"

ExitSub:
    Exit Sub

ErrHandler:
    MsgBox "Error inesperado en el proceso de limpieza: " & Err.Description, vbCritical, "Error de VBA"
    Resume ExitSub
End Sub

'==================================================================================================
' --- EVENTO: txtNombreBeneficiarioEditar_AfterUpdate
' --- Función: Convierte el texto a mayúsculas después de que el usuario termina de escribir
'==================================================================================================

Private Sub txtNombreBeneficiarioEditar_AfterUpdate()
    ' Convertir el texto a mayúsculas solo después de actualizar
    Me.txtNombreBeneficiarioEditar = UCase(Me.txtNombreBeneficiarioEditar)
End Sub

