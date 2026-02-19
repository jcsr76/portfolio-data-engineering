VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_subform_TallasDotacion"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

' VARIABLE PÚBLICA GLOBAL para este formulario
Public idColaboradorActual As Long

'==================================================================================================
' PROCEDIMIENTO PÚBLICO: CargarTallasDotacion
' Función: Recibe el id_colaborador del formulario principal
'          y lo asigna al control txtid_colaboradorTallas
'          Además carga la lista de tallas existentes
'==================================================================================================
Public Sub CargarTallasDotacion(ByVal idColaborador As Long)
    On Error Resume Next
    
    ' Si no hay colaborador, limpiar todo
    If idColaborador = 0 Then
        Me.txtid_colaboradorTallas = Null
        idColaboradorActual = 0
        Me.lstColaboradoresTallas.RowSource = ""
        Call LimpiarControlesTallas
        Exit Sub
    End If
    
    ' Guardar en variable global
    idColaboradorActual = idColaborador
    
    ' Transferir el id_colaborador al control txtid_colaboradorTallas
    Me.txtid_colaboradorTallas = idColaborador
    
    ' Limpiar controles de tallas
    Call LimpiarControlesTallas
    
    ' Cargar la lista de tallas del colaborador
    Call CargarListaTallasDotacion
    
    On Error GoTo 0
End Sub

'==================================================================================================
' PROCEDIMIENTO PRIVADO: CargarListaTallasDotacion
' Función: Carga en lstColaboradoresTallas todas las tallas del colaborador
'          Filtra por el valor en txtid_colaboradorTallas
'          Si txtid_colaboradorTallas está vacío, el listbox queda vacío
'==================================================================================================
Private Sub CargarListaTallasDotacion()
    On Error GoTo ErrHandler
    
    Dim sql As String
    Dim idColaborador As Long
    
    ' Obtener el id_colaborador del control txtid_colaboradorTallas
    idColaborador = Nz(Me.txtid_colaboradorTallas.value, 0)
    
    ' Si txtid_colaboradorTallas está vacío, limpiar listbox
    If idColaborador = 0 Then
        Me.lstColaboradoresTallas.RowSource = ""
        Exit Sub
    End If
    
    ' Construir la consulta SQL filtrando por el id_colaborador del control
    sql = "SELECT id_talla, id_colaborador, talla_pantalon, talla_camisa, talla_botas " & _
          "FROM vista_tallas_dotacion " & _
          "WHERE id_colaborador = " & idColaborador & " " & _
          "ORDER BY id_talla DESC;"
    
    ' Asignar la consulta al listbox
    Me.lstColaboradoresTallas.RowSource = sql
    
    Exit Sub

ErrHandler:
    MsgBox "Error al cargar las tallas: " & Err.Description, vbCritical, "Error"
End Sub

'==================================================================================================
' PROCEDIMIENTO PRIVADO: LimpiarControlesTallas
' Función: Limpia y reinicia los controles de tallas (combobox y textbox)
'          Se utiliza al cargar el formulario y después de guardar/eliminar
'==================================================================================================
Private Sub LimpiarControlesTallas()
    On Error Resume Next
    
    Me.txtid_talla = Null
    Me.cmbPantalon = Null
    Me.cmbCamisa = Null
    Me.cmbBotas = Null
    
    On Error GoTo 0
End Sub

' Limpiar el Fromulario
Private Sub BTN_Borrar_Click()
    LimpiarControlesTallas
End Sub

'==================================================================================================
' --- EVENTO CLICK: BTN_GuardarDotacion_Click
' --- Función: Valida datos y maneja 2 casos:
'              1. ACTUALIZAR talla existente (txtid_talla lleno)
'              2. INSERTAR nueva talla (txtid_talla vacío)
'==================================================================================================
Private Sub BTN_GuardarDotacion_Click()
    On Error GoTo ErrHandler
    
    Dim idTalla As Long
    Dim idColaborador As Long
    
    '--- 1. Obtener el id_talla del control ---
    idTalla = Nz(Me.txtid_talla, 0)
    
    '--- 2. Obtener el id_colaborador ---
    idColaborador = Nz(Me.txtid_colaboradorTallas, 0)
    
    '--- 3. DECISIÓN: ¿ACTUALIZAR o INSERTAR? ---
    If idTalla > 0 Then
        '--- CASO 1: ACTUALIZAR TALLA EXISTENTE ---
        Call ActualizarTallaDotacion(idTalla, idColaborador)
    Else
        '--- CASO 2: INSERTAR NUEVA TALLA ---
        Call InsertarTallaDotacion(idColaborador)
    End If

ExitSub:
    Exit Sub

ErrHandler:
    MsgBox "Error inesperado en el proceso: " & Err.Description, vbCritical, "Error de VBA"
    Resume ExitSub
End Sub

'==================================================================================================
' --- PROCEDIMIENTO PRIVADO: ActualizarTallaDotacion
' --- Función: Ejecuta sp_actualizar_talla_dotacion
'==================================================================================================
Private Sub ActualizarTallaDotacion(ByVal idTalla As Long, ByVal idColaborador As Long)
    On Error GoTo ErrHandler
    
    Dim usuarioActual As String
    Dim cmd As ADODB.Command
    Dim resultadoSP As Integer
    Dim tallaPantalon As String
    Dim tallaCamisa As String
    Dim tallaBotas As String
    
    '--- 1. Validación: ¿Están completos los datos? ---
    tallaPantalon = Nz(Me.cmbPantalon, "")
    tallaCamisa = Nz(Me.cmbCamisa, "")
    tallaBotas = Nz(Me.cmbBotas, "")
    
    If tallaPantalon = "" Or tallaCamisa = "" Or tallaBotas = "" Then
        MsgBox "Debe completar todos los campos de tallas (Pantalón, Camisa, Botas).", vbExclamation, "Campos incompletos"
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
        .CommandText = "sp_actualizar_talla_dotacion"
        
        .Parameters.Append .CreateParameter("p_id_talla", adInteger, adParamInput, , idTalla)
        .Parameters.Append .CreateParameter("p_talla_pantalon", adVarChar, adParamInput, 5, tallaPantalon)
        .Parameters.Append .CreateParameter("p_talla_camisa", adVarChar, adParamInput, 5, tallaCamisa)
        .Parameters.Append .CreateParameter("p_talla_botas", adVarChar, adParamInput, 5, tallaBotas)
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
            MsgBox "Las tallas de dotación se han actualizado correctamente.", vbInformation, "Actualización completada"
            Call LimpiarControlesTallas
            Call CargarListaTallasDotacion
        Case 0
            MsgBox "No se detectaron cambios en los datos.", vbInformation, "Sin cambios"
        Case -1
            MsgBox "Error en la base de datos durante la actualización.", vbCritical, "Error de MySQL"
    End Select

ExitSub:
    On Error Resume Next
    Set cmd = Nothing
    Exit Sub

ErrHandler:
    MsgBox "Error en ActualizarTallaDotacion: " & Err.Description, vbCritical, "Error"
    Resume ExitSub
End Sub

'==================================================================================================
' --- PROCEDIMIENTO PRIVADO: InsertarTallaDotacion
' --- Función: Ejecuta sp_insertar_tallas_dotacion (INSERCIÓN DE NUEVA TALLA)
'==================================================================================================
Private Sub InsertarTallaDotacion(ByVal idColaborador As Long)
    On Error GoTo ErrHandler
    
    Dim usuarioActual As String
    Dim cmd As ADODB.Command
    Dim resultadoSP As Integer
    Dim tallaPantalon As String
    Dim tallaCamisa As String
    Dim tallaBotas As String
    
    '--- 1. Validación: ¿El usuario ha seleccionado un colaborador? ---
    If idColaborador = 0 Then
        MsgBox "Debe seleccionar un colaborador de la lista principal.", vbExclamation, "Colaborador no seleccionado"
        Exit Sub
    End If
    
    '--- 2. Validación: ¿Están completos los datos? ---
    tallaPantalon = Nz(Me.cmbPantalon, "")
    tallaCamisa = Nz(Me.cmbCamisa, "")
    tallaBotas = Nz(Me.cmbBotas, "")
    
    If tallaPantalon = "" Or tallaCamisa = "" Or tallaBotas = "" Then
        MsgBox "Debe completar todos los campos de tallas (Pantalón, Camisa, Botas).", vbExclamation, "Campos incompletos"
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
        .CommandText = "sp_insertar_tallas_dotacion"
        
        .Parameters.Append .CreateParameter("p_id_colaborador", adInteger, adParamInput, , idColaborador)
        .Parameters.Append .CreateParameter("p_talla_pantalon", adVarChar, adParamInput, 5, tallaPantalon)
        .Parameters.Append .CreateParameter("p_talla_camisa", adVarChar, adParamInput, 5, tallaCamisa)
        .Parameters.Append .CreateParameter("p_talla_botas", adVarChar, adParamInput, 5, tallaBotas)
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
            MsgBox "Las tallas de dotación se han registrado correctamente.", vbInformation, "Inserción completada"
            Call LimpiarControlesTallas
            Call CargarListaTallasDotacion
        Case 0
            MsgBox "Este colaborador ya tiene tallas de dotación registradas.", vbExclamation, "Tallas duplicadas"
        Case -1
            MsgBox "Ocurrió un error en la base de datos durante la inserción.", vbCritical, "Error de MySQL"
    End Select

ExitSub:
    On Error Resume Next
    Set cmd = Nothing
    Exit Sub

ErrHandler:
    MsgBox "Error en InsertarTallaDotacion: " & Err.Description, vbCritical, "Error"
    Resume ExitSub
End Sub

'==================================================================================================
' EVENTO: lstColaboradoresTallas_Click
' Función: Cuando el usuario selecciona un registro en el listbox,
'          carga los datos en los controles: txtid_talla, cmbPantalon, cmbCamisa, cmbBotas
'==================================================================================================
Private Sub lstColaboradoresTallas_Click()
    On Error GoTo ErrHandler
    
    ' Verificar que hay un registro seleccionado
    If Me.lstColaboradoresTallas.ListIndex = -1 Then
        Exit Sub
    End If
    
    ' Cargar datos del registro seleccionado
    ' Columna 0: id_talla
    Me.txtid_talla = Me.lstColaboradoresTallas.Column(0)
    
    ' Columna 2: talla_pantalon
    Me.cmbPantalon = Me.lstColaboradoresTallas.Column(2)
    
    ' Columna 3: talla_camisa
    Me.cmbCamisa = Me.lstColaboradoresTallas.Column(3)
    
    ' Columna 4: talla_botas
    Me.cmbBotas = Me.lstColaboradoresTallas.Column(4)
    
    Exit Sub

ErrHandler:
    MsgBox "Error al cargar la talla seleccionada: " & Err.Description, vbCritical, "Error"
End Sub

'==================================================================================================
' --- EVENTO CLICK: BTN_EliminarTallasDotacion_Click
' --- Función: Valida que hay un registro seleccionado y ejecuta la eliminación
'            con confirmación del usuario
'==================================================================================================
Private Sub BTN_EliminarTallasDotacion_Click()
    On Error GoTo ErrHandler
    
    Dim idTalla As Long
    Dim idColaborador As Long
    Dim respuesta As Integer
    
    '--- 1. Obtener el id_talla del control ---
    idTalla = Nz(Me.txtid_talla, 0)
    
    '--- 2. Validación: ¿Está seleccionado un registro? ---
    If idTalla = 0 Then
        MsgBox "Debe seleccionar un registro de tallas antes de continuar.", vbExclamation, "Registro no seleccionado"
        Exit Sub
    End If
    
    '--- 3. Confirmación del usuario ---
    respuesta = MsgBox("¿Está seguro de que desea eliminar este registro de tallas de dotación?" & vbCrLf & _
                       "Esta acción no se puede deshacer.", vbQuestion + vbYesNo, "Confirmar eliminación")
    
    If respuesta <> vbYes Then
        Exit Sub
    End If
    
    '--- 4. Obtener el id_colaborador ---
    idColaborador = Nz(Me.txtid_colaboradorTallas, 0)
    
    '--- 5. Llamar al procedimiento de eliminación ---
    Call EliminarTallaDotacion(idTalla, idColaborador)

ExitSub:
    Exit Sub

ErrHandler:
    MsgBox "Error inesperado en el proceso: " & Err.Description, vbCritical, "Error de VBA"
    Resume ExitSub
End Sub

'==================================================================================================
' --- PROCEDIMIENTO PRIVADO: EliminarTallaDotacion
' --- Función: Ejecuta sp_eliminar_talla_dotacion
'==================================================================================================
Private Sub EliminarTallaDotacion(ByVal idTalla As Long, ByVal idColaborador As Long)
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
        .CommandText = "sp_eliminar_talla_dotacion"
        
        .Parameters.Append .CreateParameter("p_id_talla", adInteger, adParamInput, , idTalla)
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
            MsgBox "Las tallas de dotación se han eliminado correctamente.", vbInformation, "Eliminación completada"
            Call LimpiarControlesTallas
            Call CargarListaTallasDotacion
            Me.lstColaboradoresTallas.Requery
        Case -1
            MsgBox "Ocurrió un error en la base de datos durante la eliminación.", vbCritical, "Error de MySQL"
    End Select

ExitSub:
    On Error Resume Next
    Set cmd = Nothing
    Exit Sub

ErrHandler:
    MsgBox "Error en EliminarTallaDotacion: " & Err.Description, vbCritical, "Error"
    Resume ExitSub
End Sub


