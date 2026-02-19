VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Registro_Tallas_Colaborador"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

' Botón Borrar formulario
Private Sub BTN_Borrar_Click()
    Call Limpiar_Formulario_Tallas
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
             "WHERE (T2.tallas_dotacion = False);"

    ' 2. Asignamos la consulta al Origen de la Fila del ListBox
    Me.lstColaboradoresPendTallas.RowSource = strSQL
    
    ' Deshabilitar controles al inicio
     Call DesHabilitarControlesTallas
    
End Sub

' Cargar los datos del colaborador seleccionado
Private Sub lstColaboradoresPendTallas_AfterUpdate()
    On Error GoTo ErrHandler
    
    ' Asegurarse de que haya una selección
    If Me.lstColaboradoresPendTallas.ListIndex = -1 Then Exit Sub
    
    ' Asignar los valores de las columnas del ListBox a los controles del formulario
    Me.txtid_colaborador = Me.lstColaboradoresPendTallas.Column(0)   ' T1.id_colaborador
    Me.txtid_cc = Me.lstColaboradoresPendTallas.Column(1)            ' T1.id_cc
    Me.txtPrimerNombre = Me.lstColaboradoresPendTallas.Column(2)     ' T1.primer_nombre
    Me.txtSegundoNombre = Me.lstColaboradoresPendTallas.Column(3)    ' T1.segundo_nombre
    Me.txtPrimerApellido = Me.lstColaboradoresPendTallas.Column(4)   ' T1.primer_apellido
    Me.txtSegundoApellido = Me.lstColaboradoresPendTallas.Column(5)  ' T1.segundo_apellido
    
    ' Habilitar controles de contacto y afiliaciones
    Call HabilitarControlesTallas
    
Exit Sub

ErrHandler:
    MsgBox "Error al cargar los datos del colaborador seleccionado: " & Err.Description, vbExclamation, "Error"

End Sub
'==================================================================================================
' EVENTO CLICK DEL BOTÓN GUARDAR (Para el formulario de Tallas Dotación colaborador)
' Valida, conecta, llama al SP, actualiza la tabla local y limpia el formulario.
'==================================================================================================
Private Sub BTN_Guardar_Click()
    On Error GoTo ErrHandler
    
    Dim cmd As ADODB.Command
    Dim usuarioActual As String
    Dim resultadoSP As Integer

    '--- 1. Validación de campos obligatorios (Ajustada para mayor robustez) ---
    If Nz(Me.txtid_colaborador, 0) = 0 Then
        MsgBox "Debe seleccionar un colaborador de la lista antes de continuar.", vbExclamation, "Faltan datos"
        Exit Sub
    End If
    
    ' Se usa Trim(Nz(...)) para permitir que el usuario escriba una talla nueva que no esté en la lista.
    If Trim(Nz(Me.cmbPantalon.value, "")) = "" Then
        MsgBox "Debe seleccionar o ingresar una Talla de Pantalón.", vbExclamation, "Dato Requerido"
        Me.cmbPantalon.SetFocus
        Exit Sub
    End If
    If Trim(Nz(Me.cmbCamisa.value, "")) = "" Then
        MsgBox "Debe seleccionar o ingresar una Talla de Camisa.", vbExclamation, "Dato Requerido"
        Me.cmbCamisa.SetFocus
        Exit Sub
    End If
    If Trim(Nz(Me.cmbBotas.value, "")) = "" Then
        MsgBox "Debe seleccionar o ingresar una Talla de Botas.", vbExclamation, "Dato Requerido"
        ' Corregido el SetFocus al control correcto
        Me.cmbBotas.SetFocus
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

    '--- 3. Establecer variable de sesión ---
    cnn.Execute "SET @usuario_actual = '" & Replace(usuarioActual, "'", "''") & "';"

    '--- 4. Configurar y Ejecutar el Procedimiento Almacenado ---
    Set cmd = New ADODB.Command
    With cmd
        .ActiveConnection = cnn
        .CommandType = adCmdStoredProc
        .CommandText = "sp_insertar_tallas_dotacion"
        
        ' Asignación de parámetros
        .Parameters.Append .CreateParameter("p_id_colaborador", adInteger, adParamInput, , Me.txtid_colaborador.value)
        .Parameters.Append .CreateParameter("p_talla_pantalon", adVarChar, adParamInput, 5, Trim(Me.cmbPantalon.value))
        .Parameters.Append .CreateParameter("p_talla_camisa", adVarChar, adParamInput, 5, Trim(Me.cmbCamisa.value))
        .Parameters.Append .CreateParameter("p_talla_botas", adVarChar, adParamInput, 5, Trim(Me.cmbBotas.value))
        .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)
        .Parameters.Append .CreateParameter("p_resultado", adInteger, adParamOutput)
        
        ' Ejecutar y controlar errores de MySQL
        On Error Resume Next
        .Execute
        If cnn.Errors.Count > 0 Then
            MsgBox "Ocurrió un error al guardar los datos de las tallas: " & cnn.Errors(0).Description, vbCritical, "Error de MySQL"
            cnn.Errors.Clear
            GoTo ExitSub
        End If
        On Error GoTo ErrHandler
        
        resultadoSP = .Parameters("p_resultado").value
    End With
    
    '--- 5. Procesar resultado ---
    Select Case resultadoSP
        Case 1
            '--- INSERCIÓN EXITOSA ---
            ' Actualizar la tabla de control local para marcar la tarea como completada
            CurrentDb.Execute "UPDATE tbl_ingreso_actual SET tallas_dotacion = True WHERE id_colaborador = '" & Me.txtid_cc.value & "';", dbFailOnError
            
            MsgBox "Los datos de tallas de dotación se han guardado correctamente.", vbInformation, "Proceso completado"
            
            '--- Limpieza y Refresco Final ---
            Call Limpiar_Formulario_Tallas
            Me.lstColaboradoresPendTallas.Requery
            
        Case 0
            '--- DUPLICADO: COLABORADOR YA TIENE TALLAS ---
            ' Actualizar la tabla de control local aunque ya existía el registro
            CurrentDb.Execute "UPDATE tbl_ingreso_actual SET tallas_dotacion = True WHERE id_colaborador = '" & Me.txtid_cc.value & "';", dbFailOnError
            
            MsgBox "Este colaborador ya tiene tallas de dotación registradas." & vbCrLf & _
                   "Use el módulo de actualizaciones si desea modificarlas.", vbExclamation, "Tallas duplicadas"
            
            '--- Limpieza y Refresco Final ---
            Call Limpiar_Formulario_Tallas
            Me.lstColaboradoresPendTallas.Requery
            
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
Private Sub DesHabilitarControlesTallas()

    Me.cmbPantalon.Enabled = False
    Me.cmbCamisa.Enabled = False
    Me.cmbBotas.Enabled = False
    
End Sub

' función Habilitar controles
Private Sub HabilitarControlesTallas()
    
    Me.cmbPantalon.Enabled = True
    Me.cmbCamisa.Enabled = True
    Me.cmbBotas.Enabled = True
    
End Sub

'==================================================================================================
' FUNCIÓN PARA LIMPIAR Y REINICIAR EL FORMULARIO
' Limpia todos los controles de ingreso de datos y los deshabilita.
'==================================================================================================
Private Sub Limpiar_Formulario_Tallas()
    ' --- Limpiar campos de identificación del colaborador ---
    Me.txtid_colaborador = Null
    Me.txtid_cc = Null
    Me.txtPrimerNombre = Null
    Me.txtSegundoNombre = Null
    Me.txtPrimerApellido = Null
    Me.txtSegundoApellido = Null

    
    ' --- Limpiar Cuadros Combinados (ComboBox) ---
    Me.cmbPantalon = Null
    Me.cmbCamisa = Null
    Me.cmbBotas = Null
    
    ' --- Finalmente, deshabilitar todos los controles ---
    Call DesHabilitarControlesTallas
End Sub




