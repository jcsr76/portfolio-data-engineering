VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_subform_DatosContacto"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

' Variable pública para almacenar el ID del colaborador
Public idColaboradorAlmacenado As Long

'==================================================================================================
' EVENTO: Form_Load
' Ubicación: Subformulario subform_DatosContacto
' Función: Asegura que el subformulario esté vacío al cargarse inicialmente.
'==================================================================================================
Private Sub Form_Load()
    ' Al cargarse, el subformulario no sabe a qué colaborador pertenece.
    ' Lo inicializamos vacío por seguridad.
    Me.lstDatosContactoExistentes.RowSource = ""
    Me.txtIdColaboradorContacto = Null
    Call LimpiarControlesEdicion
End Sub

'==================================================================================================
' MÓDULO DE FORMULARIO: subform_DatosContacto
'==================================================================================================

'==================================================================================================
' PROCEDIMIENTO PÚBLICO: CargarContactosExistentes
' Función: Carga el ListBox lstDatosContactoExistentes con contactos del colaborador
' Parámetro: id_colaborador (Long) - ID del colaborador a consultar
'==================================================================================================
Public Sub CargarContactosExistentes(id_colaborador As Long)
    Dim sql As String
    
    ' Validar que id_colaborador es válido
    If Nz(id_colaborador, 0) = 0 Then
        Me.lstDatosContactoExistentes.RowSource = ""
        Me.txtIdColaboradorContacto = Null
        Exit Sub
    End If
    
    ' Conectar a MySQL si no está conectado
    If Not VerificarYReconectarMySQL() Then Exit Sub
    
    ' Construir la consulta SQL para MySQL
    sql = "SELECT id_contacto, id_colaborador, tipo, valor " & _
          "FROM vista_contactos_colaboradores " & _
          "WHERE id_colaborador = " & id_colaborador & " " & _
          "ORDER BY tipo;"
    
    ' Asignar al ListBox
    Me.lstDatosContactoExistentes.RowSource = sql
    
    ' ASIGNAR EL ID DEL COLABORADOR
    Me.txtIdColaboradorContacto = id_colaborador
    
    ' Limpiar los otros controles
    Me.txtIdContacto = Null
    Me.cmbTipoContacto = Null
    Me.txtValorContacto = Null
    
End Sub

'==================================================================================================
' EVENTO: lstDatosContactoExistentes_Click
' Se dispara cuando el usuario selecciona un contacto en el ListBox
' Función: Carga los datos del contacto seleccionado en los controles de edición
'==================================================================================================
Private Sub lstDatosContactoExistentes_Click()
    
    ' Validar que hay un registro seleccionado
    If Me.lstDatosContactoExistentes.ListIndex = -1 Then
        Exit Sub
    End If
    
    ' Obtener los valores del ListBox
    ' Column(0) = id_contacto (oculto)
    ' Column(1) = id_colaborador (oculto)
    ' Column(2) = tipo (visible)
    ' Column(3) = valor (visible)
    

    Me.txtIdContacto = Me.lstDatosContactoExistentes.Column(0)
    Me.cmbTipoContacto = Me.lstDatosContactoExistentes.Column(2)
    Me.txtValorContacto = Me.lstDatosContactoExistentes.Column(3)
    
    ' txtIdColaboradorContacto permanece con el valor cargado desde lstColaboradores_Click()
    
End Sub

'==================================================================================================
' EVENTO CLICK DEL BOTÓN GUARDAR - subform_DatosContacto
' --- VERSIÓN CORREGIDA PARA MANEJAR "NO CHANGES" ---
'==================================================================================================
Private Sub BTN_Guardar_Click()
    On Error GoTo ErrHandler
    
    Dim cmd As ADODB.Command
    Dim usuarioActual As String
    Dim hayActualizacion As Boolean
    Dim hayInsercion As Boolean
    Dim jsonContactos As String
    Dim rsTemp As DAO.Recordset
    Dim countRegistros As Long
    Dim msgActualizacion As String ' Variable para mensaje final

    '--- 1. VERIFICAR CONEXIÓN Y USUARIO ---
    If Not VerificarYReconectarMySQL() Then Exit Sub
    If cnn Is Nothing Then Set cnn = New ADODB.Connection
    If cnn.State <> adStateOpen Then cnn.Open Con

    usuarioActual = EstablecerUsuarioActual
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual. No es posible continuar.", vbCritical
        Exit Sub
    End If

    hayActualizacion = False
    hayInsercion = False

    '--- 2. VERIFICAR SI HAY DATO SELECCIONADO Y EDITADO ---
    If Nz(Me.txtIdContacto, 0) <> 0 Then
        If Not IsNull(Me.cmbTipoContacto) And Me.cmbTipoContacto <> "" And _
           Not IsNull(Me.txtValorContacto) And Me.txtValorContacto <> "" Then
            hayActualizacion = True
        End If
    End If

    '--- 3. VERIFICAR SI HAY REGISTROS EN tbl_contacto_temporal ---
    Set rsTemp = CurrentDb.OpenRecordset("SELECT COUNT(*) as cnt FROM tbl_contacto_temporal")
    countRegistros = rsTemp!cnt
    rsTemp.Close
    Set rsTemp = Nothing

    If countRegistros > 0 Then
        hayInsercion = True
    End If

    '--- 4. SI NO HAY NI ACTUALIZACIÓN NI INSERCIÓN, SALIR ---
    If Not hayActualizacion And Not hayInsercion Then
        MsgBox "No hay cambios para guardar. Selecciona un contacto para editar o agrega nuevos contactos.", vbInformation, "Sin cambios"
        Exit Sub
    End If

    msgActualizacion = "" ' Inicializar mensaje de actualización

    '--- 5. EJECUTAR ACTUALIZACIÓN SI LA HAY ---
    If hayActualizacion Then
        Set cmd = New ADODB.Command
        With cmd
            .ActiveConnection = cnn
            .CommandType = adCmdStoredProc
            .CommandText = "sp_actualizar_contacto_colaborador"
            .Parameters.Append .CreateParameter("p_id_contacto", adInteger, adParamInput, , CLng(Me.txtIdContacto))
            .Parameters.Append .CreateParameter("p_tipo", adVarChar, adParamInput, 50, Nz(Me.cmbTipoContacto, ""))
            .Parameters.Append .CreateParameter("p_valor", adVarChar, adParamInput, 255, Trim(Nz(Me.txtValorContacto, "")))
            .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)
            
            On Error Resume Next
            .Execute
            
            ' --- LÓGICA DE MANEJO DE ERRORES MEJORADA ---
            If cnn.Errors.Count > 0 Then
                ' Verificar si el error es la notificación de "no cambios"
                If InStr(1, cnn.Errors(0).Description, "No se detectaron cambios", vbTextCompare) > 0 Then
                    ' Es una notificación, no un error fatal.
                    ' Informar al usuario y limpiar los controles.
                    MsgBox cnn.Errors(0).Description, vbInformation, "Aviso"
                    ' Limpiar controles para que el usuario no intente guardar lo mismo otra vez
                    Me.txtIdContacto = Null
                    Me.cmbTipoContacto = Null
                    Me.txtValorContacto = Null
                    hayActualizacion = False ' Se marca como que la actualización ya no está pendiente.
                Else
                    ' Es un error real. Mostrarlo y salir.
                    MsgBox "Error en la actualización: " & cnn.Errors(0).Description, vbCritical
                    cnn.Errors.Clear
                    GoTo ExitSub
                End If
                cnn.Errors.Clear
            Else
                ' La actualización fue exitosa
                msgActualizacion = "El Dato de contacto se ha actualizado correctamente."
                ' Limpiar los controles después de actualizar exitosamente
            Call LimpiarControlesEdicion
           
            End If
            ' --- FIN DE LA LÓGICA MEJORADA ---
            
            On Error GoTo ErrHandler
        End With
        Set cmd = Nothing
    End If

    '--- 6. EJECUTAR INSERCIÓN SI LA HAY ---
    ' Esta sección ahora se ejecutará incluso si la actualización no hizo cambios.
    If hayInsercion Then
        jsonContactos = GenerarJSONContactos()
        
        If jsonContactos = "ERROR" Or jsonContactos = "[]" Then
            MsgBox "No se pudieron procesar los datos de contacto para insertar.", vbCritical, "Error de Datos"
            GoTo ExitSub
        End If
        
        Set cmd = New ADODB.Command
        With cmd
            .ActiveConnection = cnn
            .CommandType = adCmdStoredProc
            .CommandText = "sp_insertar_contactos_colaboradores"
            .Parameters.Append .CreateParameter("p_id_colaborador", adInteger, adParamInput, , CLng(Me.txtIdColaboradorContacto))
            .Parameters.Append .CreateParameter("p_contactos_json", adLongVarChar, adParamInput, Len(jsonContactos), jsonContactos)
            .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)
            
            On Error Resume Next
            .Execute
            If cnn.Errors.Count > 0 Then
                MsgBox "Error en la inserción: " & cnn.Errors(0).Description, vbCritical
                cnn.Errors.Clear
                GoTo ExitSub
            End If
            On Error GoTo ErrHandler
        End With
        Set cmd = Nothing
        
        Call LimpiarTablaTemporal
        
    End If

    '--- 7. MENSAJE DE ÉXITO UNIFICADO ---
    If hayActualizacion And hayInsercion Then
        MsgBox "Los Datos de Contacto se han actualizado e insertado correctamente.", vbInformation, "Proceso Completado"
    ElseIf hayActualizacion Then
        MsgBox "El Dato de Contacto se ha actualizado correctamente.", vbInformation, "Actualización Exitosa"
    ElseIf hayInsercion Then
        ' Si hubo una actualización sin cambios, msgActualizacion estará vacío.
        If msgActualizacion <> "" Then
             MsgBox msgActualizacion & vbCrLf & "Y los nuevos daots de contacto se han insertado correctamente.", vbInformation, "Proceso Completado"
        Else
             MsgBox "Los nuevos datos de contacto se han insertado correctamente.", vbInformation, "Inserción Exitosa"
        End If
    End If
    
    ' Recargar los datos de contacto existentes
    Me.CargarContactosExistentes CLng(Nz(Me.txtIdColaboradorContacto, 0))

ExitSub:
    On Error Resume Next
    Set cmd = Nothing
    Exit Sub

ErrHandler:
    MsgBox "Error inesperado: " & Err.Description, vbCritical, "Error"
    Resume ExitSub
End Sub

'==================================================================================================
' FUNCIÓN: GenerarJSONContactos
' Función: Genera JSON desde tbl_contacto_temporal para insertar en SP
' Retorna: String con JSON o "ERROR" si falla
'==================================================================================================
Private Function GenerarJSONContactos() As String
    Dim rs As DAO.Recordset
    Dim json As String
    Dim primera As Boolean

    On Error GoTo GenerarJSON_Error

    json = "["
    primera = True

    Set rs = CurrentDb.OpenRecordset("SELECT tipo, valor FROM tbl_contacto_temporal ORDER BY id")

    While Not rs.EOF
        If Not primera Then
            json = json & ","
        End If
        
        json = json & "{""tipo"":""" & rs!tipo & """,""valor"":""" & rs!valor & """}"
        primera = False
        rs.MoveNext
    Wend

    json = json & "]"

    rs.Close
    Set rs = Nothing

    GenerarJSONContactos = json
    Exit Function

GenerarJSON_Error:
    GenerarJSONContactos = "ERROR"
End Function

'==================================================================================================
' FUNCIÓN PRIVADA: LimpiarControlesEdicion
' Función: Limpia los controles relacionados con la edición de un contacto existente.
'==================================================================================================
Private Sub LimpiarControlesEdicion()
    ' Limpia los controles del formulario de edición
    Me.txtIdContacto = Null
    Me.cmbTipoContacto = Null
    Me.txtValorContacto = Null
    
    ' Opcional: Deseleccionar el ListBox para evitar confusiones
    Me.lstDatosContactoExistentes.value = Null
End Sub

'==================================================================================================
' FUNCIÓN PRIVADA: LimpiarTablaTemporal
' Función: Vacía la tabla local tbl_contacto_temporal y refresca el subformulario que la muestra.
'==================================================================================================
Private Sub LimpiarTablaTemporal()
    On Error GoTo LimpiarTemporal_Err
    
    ' Ejecuta una consulta DELETE para borrar todos los registros de la tabla temporal.
    CurrentDb.Execute "DELETE FROM tbl_contacto_temporal;", dbFailOnError
    
    ' Refresca el subformulario que muestra los datos temporales para que se vea vacío.
    ' Asegúrate de que "Subformulario_tbl_contacto_temporal" es el nombre correcto de tu control de subformulario.
    Me.[Subformulario tbl_contacto_temporal].Requery
    
    Exit Sub

LimpiarTemporal_Err:
    MsgBox "Ocurrió un error al intentar limpiar los nuevos contactos: " & Err.Description, vbCritical, "Error de Limpieza"
End Sub

'==================================================================================================
' EVENTO CLICK DEL BOTÓN LIMPIAR
' Función: Llama a las funciones de limpieza para reiniciar el formulario.
'==================================================================================================
Private Sub BTN_Borrar_Click()
    ' Preguntar al usuario para evitar borrados accidentales
    If MsgBox("¿Estás seguro de que deseas descartar todos los cambios no guardados y limpiar el formulario?", _
              vbQuestion + vbYesNo, "Confirmar Limpieza") = vbYes Then
              
        ' Llamar a las dos funciones de limpieza
        Call LimpiarControlesEdicion
        Call LimpiarTablaTemporal
        
        ' --- LÍNEA CLAVE FALTANTE ---
        ' Vaciar la lista de contactos existentes.
        Me.lstDatosContactoExistentes.RowSource = ""
        ' ----------------------------
        
        ' Enfocar un control inicial, por ejemplo, el combobox de tipo de contacto
        Me.cmbTipoContacto.SetFocus
        
    End If
End Sub


'==================================================================================================
' EVENTO CLICK DEL BOTÓN ELIMINAR REGISTRO
' Función: Elimina un dato de contacto existente seleccionado en el ListBox.
'==================================================================================================
Private Sub BTN_EliminarRegistro_Click()
    Dim cmd As ADODB.Command
    Dim usuarioActual As String
    Dim idContactoParaBorrar As Long
    
    ' --- 1. VALIDACIÓN: Asegurarse de que un contacto está seleccionado ---
    If IsNull(Me.txtIdContacto) Or Me.txtIdContacto = 0 Then
        MsgBox "Por favor, seleccione un dato de contacto de la lista para poder eliminarlo.", vbExclamation, "Ningún Dato Seleccionado"
        Exit Sub
    End If
    
    ' --- 2. CONFIRMACIÓN DEL USUARIO ---
    If MsgBox("¿Está seguro de que desea eliminar permanentemente el dato de contacto seleccionado?", _
              vbQuestion + vbYesNo + vbDefaultButton2, "Confirmar Eliminación") = vbNo Then
        Exit Sub
    End If

    On Error GoTo ErrHandler
    
    ' --- 3. PREPARACIÓN DE LA LLAMADA AL SP ---
    If Not VerificarYReconectarMySQL() Then Exit Sub
    If cnn Is Nothing Then Set cnn = New ADODB.Connection
    If cnn.State <> adStateOpen Then cnn.Open Con
    
    usuarioActual = EstablecerUsuarioActual
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual. No es posible continuar.", vbCritical
        Exit Sub
    End If
    
    idContactoParaBorrar = CLng(Me.txtIdContacto)

    ' --- 4. EJECUCIÓN DEL COMANDO ---
    Set cmd = New ADODB.Command
    With cmd
        .ActiveConnection = cnn
        .CommandType = adCmdStoredProc
        .CommandText = "sp_eliminar_contacto_colaborador"
        .Parameters.Append .CreateParameter("p_id_contacto", adInteger, adParamInput, , idContactoParaBorrar)
        .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)
        
        On Error Resume Next
        .Execute
        If cnn.Errors.Count > 0 Then
            MsgBox "Error al eliminar: " & cnn.Errors(0).Description, vbCritical
            cnn.Errors.Clear
            GoTo ExitSub
        End If
        On Error GoTo ErrHandler
    End With
    
    ' --- 5. LIMPIEZA Y ACTUALIZACIÓN POST-ELIMINACIÓN ---
    MsgBox "El dato de contacto ha sido eliminado correctamente.", vbInformation, "Eliminación Exitosa"
    
    ' Limpiar los controles de edición
    Call LimpiarControlesEdicion
    
    ' Recargar la lista de contactos para que el registro eliminado desaparezca
    Me.CargarContactosExistentes CLng(Nz(Me.txtIdColaboradorContacto, 0))

ExitSub:
    On Error Resume Next
    Set cmd = Nothing
    Exit Sub

ErrHandler:
    MsgBox "Error inesperado durante la eliminación: " & Err.Description, vbCritical, "Error"
    Resume ExitSub
End Sub





