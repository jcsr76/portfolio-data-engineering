VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Registrar_Beneficiarios_Colaborador"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

Private Sub BTN_Borrar_Click()
    Call Limpiar_Formulario_Beneficiarios
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
             "WHERE (T2.beneficiarios = False);"

    ' 2. Asignamos la consulta al Origen de la Fila del ListBox
    Me.lstPendienteBeneficiarios.RowSource = strSQL
    
    ' Deshabilitar controles al inicio
     Call DeshabilitarControlesBeneficiarios
    
End Sub

' Cargar los datos del colaborador seleccionado
Private Sub lstPendienteBeneficiarios_AfterUpdate()
    On Error GoTo ErrHandler
    
    ' Asegurarse de que haya una selección
    If Me.lstPendienteBeneficiarios.ListIndex = -1 Then Exit Sub
    
    ' Asignar los valores de las columnas del ListBox a los controles del formulario
    Me.txtid_colaborador = Me.lstPendienteBeneficiarios.Column(0)   ' T1.id_colaborador
    Me.txtid_cc = Me.lstPendienteBeneficiarios.Column(1)            ' T1.id_cc
    Me.txtPrimerNombre = Me.lstPendienteBeneficiarios.Column(2)     ' T1.primer_nombre
    Me.txtSegundoNombre = Me.lstPendienteBeneficiarios.Column(3)    ' T1.segundo_nombre
    Me.txtPrimerApellido = Me.lstPendienteBeneficiarios.Column(4)   ' T1.primer_apellido
    Me.txtSegundoApellido = Me.lstPendienteBeneficiarios.Column(5)  ' T1.segundo_apellido
    
    ' Habilitar controles de contacto y afiliaciones
    Call HabilitarControlesBeneficiarios
    
Exit Sub

ErrHandler:
    MsgBox "Error al cargar los datos del colaborador seleccionado: " & Err.Description, vbExclamation, "Error"

End Sub

'==================================================================================================
' EVENTO CLICK DEL BOTÓN GUARDAR (Para el formulario de Beneficiarios)
' Implementa la lógica condicional para guardar con o sin beneficiarios.
'==================================================================================================
Private Sub BTN_Guardar_Click()
    On Error GoTo ErrHandler
    
    Dim usuarioActual As String
    Dim jsonBeneficiarios As String
    Dim cmd As ADODB.Command
    Dim resultadoSP As Integer
    
    '--- 1. Validación inicial: Asegurarse de que hay un colaborador seleccionado ---
    If Nz(Me.txtid_colaborador, 0) = 0 Then
        MsgBox "Debe seleccionar un colaborador de la lista antes de continuar.", vbExclamation, "Faltan datos"
        Exit Sub
    End If
    
    '--- 2. Lógica Condicional: ¿El colaborador tiene beneficiarios? ---
    
    If Me.chkSinBeneficiarios.value = True Then
        '-- CASO A: EL COLABORADOR NO TIENE BENEFICIARIOS --
        
        ' Desvincula el subformulario
        Me.[frm_tbl_beneficiarios_temporal].SourceObject = ""
        CurrentDb.Execute "DELETE FROM tbl_beneficiarios_temporal;", dbFailOnError
        Me.[frm_tbl_beneficiarios_temporal].SourceObject = "frm_tbl_beneficiarios_temporal"
        
        ' Actualizar la tabla de control local
        CurrentDb.Execute "UPDATE tbl_ingreso_actual SET beneficiarios = True WHERE id_colaborador = '" & Me.txtid_cc.value & "';", dbFailOnError
        
        MsgBox "Se ha registrado correctamente que el colaborador no tiene beneficiarios.", vbInformation, "Proceso completado"

    Else
        '-- CASO B: EL COLABORADOR SÍ TIENE BENEFICIARIOS --
        
        ' Validación: Asegurarse de que se ha ingresado al menos un beneficiario.
        If DCount("*", "tbl_beneficiarios_temporal") = 0 Then
            MsgBox "Debe ingresar al menos un beneficiario en la tabla, o marcar la casilla 'Sin Beneficiarios' para continuar.", vbExclamation, "Faltan datos"
            Exit Sub
        End If
        
        ' Generar el JSON a partir de la tabla temporal.
        jsonBeneficiarios = GenerarJSONBeneficiarios(Me.frm_tbl_beneficiarios_temporal.Form)
        If jsonBeneficiarios = "ERROR" Or jsonBeneficiarios = "[]" Then
            MsgBox "No se pudieron procesar los datos de los beneficiarios. Por favor, revise la tabla.", vbCritical, "Error de Datos"
            Exit Sub
        End If
        
        ' Conexión a MySQL y obtención de usuario.
        If Not VerificarYReconectarMySQL() Then Exit Sub
        If cnn Is Nothing Then Set cnn = New ADODB.Connection
        If cnn.State <> adStateOpen Then cnn.Open Con
        usuarioActual = EstablecerUsuarioActual
        If usuarioActual = "" Then
            MsgBox "No se pudo obtener el usuario actual. No es posible continuar.", vbCritical
            Exit Sub
        End If

        ' Configurar y Ejecutar el Procedimiento Almacenado.
        Set cmd = New ADODB.Command
        With cmd
            .ActiveConnection = cnn
            .CommandType = adCmdStoredProc
            .CommandText = "sp_insertar_beneficiarios"
            
            .Parameters.Append .CreateParameter("p_id_colaborador", adInteger, adParamInput, , Me.txtid_colaborador.value)
            .Parameters.Append .CreateParameter("p_beneficiarios_json", adLongVarChar, adParamInput, Len(jsonBeneficiarios), jsonBeneficiarios)
            .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)
            .Parameters.Append .CreateParameter("p_resultado", adInteger, adParamOutput)
            
            On Error Resume Next
            .Execute
            If cnn.Errors.Count > 0 Then
                MsgBox "Ocurrió un error al guardar los beneficiarios en el servidor: " & cnn.Errors(0).Description, vbCritical, "Error de MySQL"
                cnn.Errors.Clear
                GoTo ExitSub
            End If
            On Error GoTo ErrHandler
            
            resultadoSP = .Parameters("p_resultado").value
        End With

        ' Procesar resultado del SP
        Select Case resultadoSP
            Case 1
                '--- ÉXITO: Beneficiarios insertados ---
                Me.[frm_tbl_beneficiarios_temporal].SourceObject = ""
                CurrentDb.Execute "DELETE FROM tbl_beneficiarios_temporal;", dbFailOnError
                Me.[frm_tbl_beneficiarios_temporal].SourceObject = "frm_tbl_beneficiarios_temporal"
                
                CurrentDb.Execute "UPDATE tbl_ingreso_actual SET beneficiarios = True WHERE id_colaborador = '" & Me.txtid_cc.value & "';", dbFailOnError
                
                MsgBox "Los beneficiarios se han guardado correctamente.", vbInformation, "Proceso completado"
                
            Case 0
                '--- DUPLICADO: Ya existen beneficiarios ---
                Me.[frm_tbl_beneficiarios_temporal].SourceObject = ""
                CurrentDb.Execute "DELETE FROM tbl_beneficiarios_temporal;", dbFailOnError
                Me.[frm_tbl_beneficiarios_temporal].SourceObject = "frm_tbl_beneficiarios_temporal"
                
                CurrentDb.Execute "UPDATE tbl_ingreso_actual SET beneficiarios = True WHERE id_colaborador = '" & Me.txtid_cc.value & "';", dbFailOnError
                
                MsgBox "Este colaborador ya tiene beneficiarios registrados." & vbCrLf & _
                       "Use el módulo de actualizaciones si desea modificarlos.", vbExclamation, "Beneficiarios duplicados"
                
            Case -1
                '--- ERROR SQL ---
                Me.[frm_tbl_beneficiarios_temporal].SourceObject = ""
                CurrentDb.Execute "DELETE FROM tbl_beneficiarios_temporal;", dbFailOnError
                Me.[frm_tbl_beneficiarios_temporal].SourceObject = "frm_tbl_beneficiarios_temporal"
                
                MsgBox "Ocurrió un error en la base de datos durante la inserción.", vbCritical, "Error de MySQL"
                Me.[frm_tbl_beneficiarios_temporal].Requery
        End Select
    End If
    
    '--- 3. Limpieza y Refresco Final (se ejecuta para ambos casos) ---
    Call Limpiar_Formulario_Beneficiarios
    Me.lstPendienteBeneficiarios.Requery

ExitSub:
    On Error Resume Next
    Set cmd = Nothing
    Exit Sub

ErrHandler:
    MsgBox "Error inesperado en el proceso de guardado: " & Err.Description, vbCritical, "Error de VBA"
    Resume ExitSub
End Sub

' función Deshabilitar controles
Private Sub DeshabilitarControlesBeneficiarios()

    Me.[frm_tbl_beneficiarios_temporal].Enabled = False
    
    Me.chkSinBeneficiarios.Enabled = False

End Sub

' función Habilitar controles
Private Sub HabilitarControlesBeneficiarios()

    Me.[frm_tbl_beneficiarios_temporal].Enabled = True
    
    Me.chkSinBeneficiarios.Enabled = True
    
End Sub

'==================================================================================================
' EVENTO AL HACER CLIC EN EL CHECKBOX 'Sin Beneficiarios' (Versión Corregida)
' Habilita/deshabilita el subformulario y solo pregunta si hay datos que borrar.
'==================================================================================================
Private Sub chkSinBeneficiarios_Click()
    On Error GoTo ErrHandler
    
    ' Si el usuario MARCA la casilla "Sin Beneficiarios"
    If Me.chkSinBeneficiarios.value = True Then
        
        ' Primero, contamos cuántos beneficiarios hay en la tabla temporal.
        If DCount("*", "tbl_beneficiarios_temporal") > 0 Then
        
            ' Si hay registros, SÍ mostramos el mensaje de confirmación.
            If MsgBox("¿Está seguro que este colaborador no tiene beneficiarios? Se borrarán los datos que ya ha ingresado.", vbQuestion + vbYesNo, "Confirmar Borrado") = vbYes Then
                ' El usuario confirmó: Borramos, deshabilitamos y refrescamos.
                CurrentDb.Execute "DELETE FROM tbl_beneficiarios_temporal;", dbFailOnError
                Me.[frm_tbl_beneficiarios_temporal].Requery
                Me.[frm_tbl_beneficiarios_temporal].Enabled = False
            Else
                ' El usuario canceló: revertimos el check y no hacemos nada más.
                Me.chkSinBeneficiarios.value = False
                Me.[frm_tbl_beneficiarios_temporal].Enabled = True
            End If
            
        Else
            ' Si NO hay registros, NO molestamos al usuario.
            ' Simplemente deshabilitamos el subformulario.
            Me.[frm_tbl_beneficiarios_temporal].Enabled = False
            ' (Opcional, por seguridad) Ejecutamos la limpieza que no hará nada.
            CurrentDb.Execute "DELETE FROM tbl_beneficiarios_temporal;", dbFailOnError
            Me.[frm_tbl_beneficiarios_temporal].Requery
        End If
        
    Else
        ' Si el usuario DESMARCA la casilla, simplemente habilitamos el subformulario.
        Me.[frm_tbl_beneficiarios_temporal].Enabled = True
    End If
    
Exit Sub

ErrHandler:
    MsgBox "Error en el evento del CheckBox: " & Err.Description, vbExclamation, "Error"
End Sub

'==================================================================================================
' FUNCIÓN PARA CONVERTIR LOS BENEFICIARIOS A FORMATO JSON
' Lee la tabla tbl_beneficiarios_temporal y la convierte en una cadena JSON.
'==================================================================================================
Private Function GenerarJSONBeneficiarios(subfrm As Form) As String
    On Error GoTo ErrHandler
    
    Dim rs As DAO.Recordset
    Dim jsonArray As String
    Dim jsonItem As String
    Dim firstItem As Boolean
    Dim fechaFormateada As String
    
    Set rs = subfrm.RecordsetClone
    
    If rs.RecordCount = 0 Then
        GenerarJSONBeneficiarios = "[]"
        Exit Function
    End If
    
    rs.MoveFirst
    jsonArray = "["
    firstItem = True
    
    Do While Not rs.EOF
        If Not firstItem Then
            jsonArray = jsonArray & ","
        End If
        
        ' Formatear la fecha al formato YYYY-MM-DD que MySQL entiende.
        ' Si la fecha es nula, se pasa un string vacío.
        If IsNull(rs!fecha_nacimiento) Then
            fechaFormateada = ""
        Else
            fechaFormateada = Format(rs!fecha_nacimiento, "yyyy-mm-dd")
        End If
        
        ' Construir el objeto JSON para el beneficiario actual.
        jsonItem = "{""nombre"":""" & Replace(rs!nombre, """", "\""") & """," & _
                   """genero"":""" & rs!genero & """," & _
                   """fecha_nacimiento"":""" & fechaFormateada & """}"
                   
        jsonArray = jsonArray & jsonItem
        
        firstItem = False
        rs.MoveNext
    Loop
    
    jsonArray = jsonArray & "]"
    GenerarJSONBeneficiarios = jsonArray
    
Exit Function

ErrHandler:
    GenerarJSONBeneficiarios = "ERROR"
    MsgBox "Error al generar el JSON de beneficiarios: " & Err.Description, vbCritical, "Error en JSON"
End Function

'==================================================================================================
' FUNCIÓN PARA LIMPIAR Y REINICIAR EL FORMULARIO DE BENEFICIARIOS (Versión Corregida)
'==================================================================================================
Private Sub Limpiar_Formulario_Beneficiarios()
    On Error GoTo ErrHandler

    ' --- Limpiar campos de identificación del colaborador ---
    Me.txtid_colaborador = Null
    Me.txtid_cc = Null
    Me.txtPrimerNombre = Null
    Me.txtSegundoNombre = Null
    Me.txtPrimerApellido = Null
    Me.txtSegundoApellido = Null
    
    ' --- AJUSTE: Limpiar la tabla temporal de beneficiarios ---
    CurrentDb.Execute "DELETE FROM tbl_beneficiarios_temporal;", dbFailOnError
    ' Refrescar el subformulario para que se muestre vacío visualmente.
    Me.[frm_tbl_beneficiarios_temporal].Requery
    
    ' --- Reiniciar el CheckBox a su estado por defecto ---
    Me.chkSinBeneficiarios.value = False
    
    ' --- Finalmente, deshabilitar todos los controles de edición ---
    Call DeshabilitarControlesBeneficiarios

Exit Sub

ErrHandler:
    MsgBox "Error durante la limpieza del formulario: " & Err.Description, vbExclamation, "Error"

End Sub







