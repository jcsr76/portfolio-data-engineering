VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Registro_Datos_Contacto_Seguridad_Social"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
    Option Compare Database

Private Sub BTN_Borrar_Click()

    ' Limpiar formulario
    Call Limpiar_Formulario_Completo
    
    ' forzar la actualización explícita de los controles con origen de datos
    Me.lstPorActualizarContacto.Requery
    Me.[Subformulario tbl_contacto_temporal].Requery
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
             "WHERE (T2.contactos_colaboradores = False) AND (T2.seguridad_social = False);"

    ' 2. Asignamos la consulta al Origen de la Fila del ListBox
    Me.lstPorActualizarContacto.RowSource = strSQL
    
    ' Deshabilitar controles al inicio
    Call DeshabilitarControlesContacto
    
End Sub

Private Sub lstPorActualizarContacto_AfterUpdate()
    On Error GoTo ErrHandler
    
    ' Asegurarse de que haya una selección
    If Me.lstPorActualizarContacto.ListIndex = -1 Then Exit Sub
    
    ' Asignar los valores de las columnas del ListBox a los controles del formulario
    Me.txtid_colaborador = Me.lstPorActualizarContacto.Column(0)   ' T1.id_colaborador
    Me.txtid_cc = Me.lstPorActualizarContacto.Column(1)            ' T1.id_cc
    Me.txtPrimerNombre = Me.lstPorActualizarContacto.Column(2)     ' T1.primer_nombre
    Me.txtSegundoNombre = Me.lstPorActualizarContacto.Column(3)    ' T1.segundo_nombre
    Me.txtPrimerApellido = Me.lstPorActualizarContacto.Column(4)   ' T1.primer_apellido
    Me.txtSegundoApellido = Me.lstPorActualizarContacto.Column(5)  ' T1.segundo_apellido
    
    ' Habilitar controles de contacto y afiliaciones
    Call HabilitarControlesContacto
    
Exit Sub

ErrHandler:
    MsgBox "Error al cargar los datos del colaborador seleccionado: " & Err.Description, vbExclamation, "Error"

End Sub

'==================================================================================================
' EVENTO CLICK DEL BOTÓN GUARDAR (Versión Corregida para evitar error de refresco)
'==================================================================================================
Private Sub BTN_Guardar_Click()
    On Error GoTo ErrHandler
    
    Dim rs As DAO.Recordset
    Dim FaltanDatos As Boolean
    Dim cmd As ADODB.Command
    Dim jsonContactos As String
    Dim usuarioActual As String
    Dim resultadoSP As Integer
    
    ' 1. Validaciones
    Set rs = Me.[Subformulario tbl_contacto_temporal].Form.RecordsetClone
    If rs.RecordCount = 0 Then
        MsgBox "Debe ingresar por lo menos un dato de contacto del colaborador antes de continuar.", vbExclamation, "Faltan datos"
        Exit Sub
    End If
    
    FaltanDatos = False
    If Nz(Me.txtCesantias, "") = "" Then FaltanDatos = True
    If Nz(Me.txtPensiones, "") = "" Then FaltanDatos = True
    If Nz(Me.txtEPS, "") = "" Then FaltanDatos = True
    If Nz(Me.txtARL, "") = "" Then FaltanDatos = True
    If Nz(Me.txtCCF, "") = "" Then FaltanDatos = True
    If Nz(Me.cmbRiesgo, "") = "" Then FaltanDatos = True
    
    If FaltanDatos Then
        MsgBox "Debe completar todos los campos obligatorios (Cesantías, Pensiones, EPS, ARL, Riesgo y CCF).", vbExclamation, "Faltan datos"
        Exit Sub
    End If
    
    ' 2. Conexión y Usuario
    If Not VerificarYReconectarMySQL() Then Exit Sub
    If cnn Is Nothing Then Set cnn = New ADODB.Connection
    If cnn.State <> adStateOpen Then cnn.Open Con
    usuarioActual = EstablecerUsuarioActual
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual. No es posible continuar.", vbCritical
        Exit Sub
    End If
    
    ' 3. Generar JSON
    jsonContactos = GenerarJSONContactos(Me.[Subformulario tbl_contacto_temporal].Form)
    If jsonContactos = "ERROR" Or jsonContactos = "[]" Then
        MsgBox "No se pudieron procesar los datos de contacto o no se ingresó ninguno.", vbCritical, "Error de Datos"
        Exit Sub
    End If
    
    ' 4. Ejecutar SP
    Set cmd = New ADODB.Command
    With cmd
        .ActiveConnection = cnn
        .CommandType = adCmdStoredProc
        .CommandText = "sp_insertar_contactos_segsocial"
        .Parameters.Append .CreateParameter("p_id_empleado", adInteger, adParamInput, , Me.txtid_colaborador.value)
        .Parameters.Append .CreateParameter("p_cesantias", adVarChar, adParamInput, 100, Me.txtCesantias.value)
        .Parameters.Append .CreateParameter("p_pension", adVarChar, adParamInput, 100, Me.txtPensiones.value)
        .Parameters.Append .CreateParameter("p_eps", adVarChar, adParamInput, 100, Me.txtEPS.value)
        .Parameters.Append .CreateParameter("p_arl", adVarChar, adParamInput, 100, Me.txtARL.value)
        .Parameters.Append .CreateParameter("p_riesgo", adVarChar, adParamInput, 5, Me.cmbRiesgo.value)
        .Parameters.Append .CreateParameter("p_ccf", adVarChar, adParamInput, 100, Me.txtCCF.value)
        .Parameters.Append .CreateParameter("p_contactos_json", adLongVarChar, adParamInput, Len(jsonContactos), jsonContactos)
        .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)
        .Parameters.Append .CreateParameter("p_resultado", adInteger, adParamOutput)
        
        On Error Resume Next
        .Execute
        If cnn.Errors.Count > 0 Then
            MsgBox "Ocurrió un error al guardar los datos en el servidor: " & cnn.Errors(0).Description, vbCritical, "Error de MySQL"
            cnn.Errors.Clear
            GoTo ExitSub
        End If
        On Error GoTo ErrHandler
        
        resultadoSP = .Parameters("p_resultado").value
    End With

    ' 5. Procesar resultado
    Select Case resultadoSP
        Case 0
            '--- ÉXITO: Ambos insertados ---
            Me.[Subformulario tbl_contacto_temporal].SourceObject = ""
            CurrentDb.Execute "DELETE FROM tbl_contacto_temporal;", dbFailOnError
            Me.[Subformulario tbl_contacto_temporal].SourceObject = "Subformulario tbl_contacto_temporal"
            
            CurrentDb.Execute "UPDATE tbl_ingreso_actual SET " & _
                                "contactos_colaboradores = True, " & _
                                "seguridad_social = True " & _
                              "WHERE id_colaborador = '" & Me.txtid_cc.value & "';", dbFailOnError
            
            MsgBox "Los datos de contacto y seguridad social se han guardado correctamente.", vbInformation, "Proceso completado"
            
            Call Limpiar_Formulario_Completo
            Me.lstPorActualizarContacto.Requery
            Me.[Subformulario tbl_contacto_temporal].Requery
            
        Case 1
            '--- Solo seguridad social insertada (contactos ya existían) ---
            Me.[Subformulario tbl_contacto_temporal].SourceObject = ""
            CurrentDb.Execute "DELETE FROM tbl_contacto_temporal;", dbFailOnError
            Me.[Subformulario tbl_contacto_temporal].SourceObject = "Subformulario tbl_contacto_temporal"
            
            CurrentDb.Execute "UPDATE tbl_ingreso_actual SET " & _
                                "contactos_colaboradores = True, " & _
                                "seguridad_social = True " & _
                              "WHERE id_colaborador = '" & Me.txtid_cc.value & "';", dbFailOnError
            
            MsgBox "Se guardaron los datos de seguridad social." & vbCrLf & _
                   "Los datos de contacto ya estaban registrados para este colaborador.", vbInformation, "Proceso completado parcialmente"
            
            Call Limpiar_Formulario_Completo
            Me.lstPorActualizarContacto.Requery
            Me.[Subformulario tbl_contacto_temporal].Requery
            
        Case 2
            '--- Ambos existen - bloquea ---
            Me.[Subformulario tbl_contacto_temporal].SourceObject = ""
            CurrentDb.Execute "DELETE FROM tbl_contacto_temporal;", dbFailOnError
            Me.[Subformulario tbl_contacto_temporal].SourceObject = "Subformulario tbl_contacto_temporal"
            
            CurrentDb.Execute "UPDATE tbl_ingreso_actual SET " & _
                                "contactos_colaboradores = True, " & _
                                "seguridad_social = True " & _
                              "WHERE id_colaborador = '" & Me.txtid_cc.value & "';", dbFailOnError
            
            MsgBox "Este colaborador ya tiene registrados datos de contacto y seguridad social." & vbCrLf & _
                   "Use el módulo de actualizaciones si desea modificarlos.", vbExclamation, "Datos duplicados"
            
            Call Limpiar_Formulario_Completo
            Me.lstPorActualizarContacto.Requery
            Me.[Subformulario tbl_contacto_temporal].Requery
            
        Case 3
            '--- Solo contactos insertados (seguridad social ya existía) ---
            Me.[Subformulario tbl_contacto_temporal].SourceObject = ""
            CurrentDb.Execute "DELETE FROM tbl_contacto_temporal;", dbFailOnError
            Me.[Subformulario tbl_contacto_temporal].SourceObject = "Subformulario tbl_contacto_temporal"
            
            CurrentDb.Execute "UPDATE tbl_ingreso_actual SET " & _
                                "contactos_colaboradores = True, " & _
                                "seguridad_social = True " & _
                              "WHERE id_colaborador = '" & Me.txtid_cc.value & "';", dbFailOnError
            
            MsgBox "Se guardaron los datos de contacto." & vbCrLf & _
                   "Los datos de seguridad social ya estaban registrados para este colaborador.", vbInformation, "Proceso completado parcialmente"
            
            Call Limpiar_Formulario_Completo
            Me.lstPorActualizarContacto.Requery
            Me.[Subformulario tbl_contacto_temporal].Requery
            
        Case -1
            '--- Error SQL ---
            Me.[Subformulario tbl_contacto_temporal].SourceObject = ""
            CurrentDb.Execute "DELETE FROM tbl_contacto_temporal;", dbFailOnError
            Me.[Subformulario tbl_contacto_temporal].SourceObject = "Subformulario tbl_contacto_temporal"
            
            MsgBox "Ocurrió un error en la base de datos durante la inserción.", vbCritical, "Error de MySQL"
            Me.[Subformulario tbl_contacto_temporal].Requery
    End Select

ExitSub:
    On Error Resume Next
    rs.Close
    Set rs = Nothing
    Set cmd = Nothing
    Exit Sub

ErrHandler:
    MsgBox "Error inesperado en el proceso de guardado: " & Err.Description, vbCritical, "Error de VBA"
    Resume ExitSub
End Sub

' función Deshabilitar controles
Private Sub DeshabilitarControlesContacto()
    Me.txtCesantias.Enabled = False
    Me.txtPensiones.Enabled = False
    Me.txtEPS.Enabled = False
    Me.txtARL.Enabled = False
    Me.txtCCF.Enabled = False
    Me.cmbRiesgo.Enabled = False
    Me.[Subformulario tbl_contacto_temporal].Enabled = False
End Sub

' función Habilitar controles
Private Sub HabilitarControlesContacto()
    Me.txtCesantias.Enabled = True
    Me.txtPensiones.Enabled = True
    Me.txtEPS.Enabled = True
    Me.txtARL.Enabled = True
    Me.txtCCF.Enabled = True
    Me.cmbRiesgo.Enabled = True
    Me.[Subformulario tbl_contacto_temporal].Enabled = True
End Sub

'==================================================================================================
' FUNCIÓN PARA CONVERTIR LOS REGISTROS DE CONTACTO A FORMATO JSON
' Lee la tabla local tbl_contacto_temporal a través del subformulario y la convierte
' en una cadena de texto JSON para ser enviada al Procedimiento Almacenado.
'==================================================================================================
Private Function GenerarJSONContactos(subfrm As Form) As String
    On Error GoTo ErrHandler
    
    Dim rs As DAO.Recordset
    Dim jsonArray As String
    Dim jsonItem As String
    Dim firstItem As Boolean
    
    ' Usar RecordsetClone es la forma más segura y eficiente de leer los datos de un subformulario
    Set rs = subfrm.RecordsetClone
    
    If rs.RecordCount = 0 Then
        GenerarJSONContactos = "[]" ' Devuelve un array JSON vacío si no hay contactos
        Exit Function
    End If
    
    rs.MoveFirst
    jsonArray = "["
    firstItem = True
    
    Do While Not rs.EOF
        ' Añadir una coma antes de cada elemento, excepto el primero
        If Not firstItem Then
            jsonArray = jsonArray & ","
        End If
        
        ' Construir el objeto JSON para el registro actual.
        ' Se reemplazan las comillas dobles dentro del valor para evitar un JSON inválido.
        jsonItem = "{""tipo"":""" & rs!tipo & """,""valor"":""" & Replace(rs!valor, """", "\""") & """}"
        jsonArray = jsonArray & jsonItem
        
        firstItem = False
        rs.MoveNext
    Loop
    
    jsonArray = jsonArray & "]"
    GenerarJSONContactos = jsonArray
    
Exit Function

ErrHandler:
    GenerarJSONContactos = "ERROR"
    MsgBox "Error al generar el JSON de contactos: " & Err.Description, vbCritical, "Error en JSON"
End Function


'==================================================================================================
' FUNCIÓN PARA LIMPIAR Y REINICIAR EL FORMULARIO
'==================================================================================================
Private Sub Limpiar_Formulario_Completo()
    ' Limpiar controles principales del formulario
    Me.txtid_colaborador = Null
    Me.txtid_cc = Null
    Me.txtPrimerNombre = Null
    Me.txtSegundoNombre = Null
    Me.txtPrimerApellido = Null
    Me.txtSegundoApellido = Null
    
    ' Limpiar controles de datos de seguridad social
    Me.txtCesantias = Null
    Me.txtPensiones = Null
    Me.txtEPS = Null
    Me.txtARL = Null
    Me.txtCCF = Null
    Me.cmbRiesgo = Null
    
    ' Deshabilitar los controles de edición hasta que se seleccione un nuevo colaborador
    Call DeshabilitarControlesContacto
End Sub

'==================================================================================================
' --- EVENTOS: AfterUpdate para convertir a MAYÚSCULAS
' --- Función: Se dispara después de editar un campo para convertir su contenido a mayúsculas.
'            Se aplican en el formulario Datos_Contacto_Seguridad_Social
'==================================================================================================

Private Sub txtCesantias_AfterUpdate()
    Me.txtCesantias = UCase(Me.txtCesantias)
End Sub

Private Sub txtPensiones_AfterUpdate()
    Me.txtPensiones = UCase(Me.txtPensiones)
End Sub

Private Sub txtEPS_AfterUpdate()
    Me.txtEPS = UCase(Me.txtEPS)
End Sub

Private Sub txtARL_AfterUpdate()
    Me.txtARL = UCase(Me.txtARL)
End Sub

Private Sub txtCCF_AfterUpdate()
    Me.txtCCF = UCase(Me.txtCCF)
End Sub




