VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_subform_SeguridadSocial"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

'==================================================================================================
' MÓDULO DE FORMULARIO: subform_SeguridadSocial
'==================================================================================================

'==================================================================================================
' EVENTO: Form_Load
' Función: Asegura que el subformulario esté completamente vacío al cargarse inicialmente.
'==================================================================================================
Private Sub Form_Load()
    Call Limpiar_Formulario_Completo
End Sub

'==================================================================================================
' PROCEDIMIENTO PÚBLICO: CargarDatosSeguridadSocial
' Función: Carga el ListBox y los controles con los datos del colaborador.
'==================================================================================================
Public Sub CargarDatosSeguridadSocial(id_colaborador As Long)
    Dim sql As String
    
    ' Limpiar el formulario para asegurar un estado limpio antes de cargar nuevos datos.
    Call Limpiar_Formulario_Completo
    
    ' Si el id_colaborador es 0, el formulario permanece limpio.
    If Nz(id_colaborador, 0) = 0 Then
        Exit Sub
    End If
    
    ' Cargar el ID en el control de texto del subformulario.
    Me.txtid_colaboradorSeguridadSocial = id_colaborador
    
    ' Conectar a MySQL si es necesario.
    If Not VerificarYReconectarMySQL() Then Exit Sub
    
    ' Construir la consulta SQL, usando 'id_empleado' en el WHERE.
    sql = "SELECT id_seguridad, id_empleado, cesantias, pension, eps, arl, riesgo, ccf " & _
          "FROM vista_seguridad_social " & _
          "WHERE id_empleado = " & id_colaborador & ";"
          
    ' Asignar la consulta al Origen de la Fila (RowSource) del ListBox.
    Me.lstSeguridadSocialColaborador.RowSource = sql
    Me.lstSeguridadSocialColaborador.Requery ' Forzar la actualización del ListBox.
    
End Sub

'==================================================================================================
' EVENTO: lstSeguridadSocialColaborador_Click
' Función: Carga los datos del registro seleccionado en los controles de edición del formulario.
' --- VERSIÓN CORREGIDA ---
'==================================================================================================
Private Sub lstSeguridadSocialColaborador_Click()
    ' Validar que hay un registro seleccionado
    If Me.lstSeguridadSocialColaborador.ListIndex = -1 Then
        Exit Sub
    End If
    
    ' --- AJUSTE CLAVE: Cargar el id_seguridad en el control de texto ---
    ' Asumimos que id_seguridad es la primera columna (índice 0) de tu ListBox.
    Me.txtIdSeguridad = Me.lstSeguridadSocialColaborador.Column(0)
    
    ' Asignar los valores del resto de las columnas a los controles de edición
    Me.txtCesantias = Me.lstSeguridadSocialColaborador.Column(2)
    Me.txtPensiones = Me.lstSeguridadSocialColaborador.Column(3)
    Me.txtEPS = Me.lstSeguridadSocialColaborador.Column(4)
    Me.txtARL = Me.lstSeguridadSocialColaborador.Column(5)
    Me.cmbRiesgo = Me.lstSeguridadSocialColaborador.Column(6)
    Me.txtCCF = Me.lstSeguridadSocialColaborador.Column(7)
    
End Sub

'==================================================================================================
' BOTÓN: BTN_Borrar_Click
' Función: Llama a la rutina de limpieza principal.
'==================================================================================================
Private Sub BTN_Borrar_Click()
    ' Preguntar al usuario para evitar limpiar datos por accidente.
    If MsgBox("¿Está seguro de que desea limpiar todos los campos de este formulario?", _
        vbQuestion + vbYesNo, "Confirmar Limpieza") = vbYes Then
        Call Limpiar_Formulario_Completo
    End If
End Sub

'==================================================================================================
' EVENTO CLICK DEL BOTÓN GUARDAR - subform_SeguridadSocial
' --- VERSIÓN CON VALIDACIÓN CONDICIONAL ---
'==================================================================================================
Private Sub BTN_Guardar_Click()
    On Error GoTo ErrHandler
    
    Dim cmd As ADODB.Command
    Dim usuarioActual As String
    Dim idSeguridad As Long
    Dim idColaborador As Long
    Dim filasAfectadas As Long

    ' Validaciones iniciales
    idColaborador = CLng(Nz(Me.txtid_colaboradorSeguridadSocial, 0))
    If idColaborador = 0 Then
        MsgBox "No hay un colaborador seleccionado. No se pueden guardar los datos.", vbCritical, "Error de Datos"
        Exit Sub
    End If
    
    idSeguridad = CLng(Nz(Me.txtIdSeguridad, 0))
    
    If idSeguridad = 0 Then ' Solo para inserciones
        If Trim(Nz(Me.txtEPS, "")) = "" Then
            MsgBox "Para un nuevo registro, el campo EPS es obligatorio.", vbExclamation, "Dato Requerido"
            Me.txtEPS.SetFocus
            Exit Sub
        End If
    End If
    
    ' Conexión y obtención de usuario
    If Not VerificarYReconectarMySQL() Then Exit Sub
    If cnn Is Nothing Then Set cnn = New ADODB.Connection
    If cnn.State <> adStateOpen Then cnn.Open Con
    usuarioActual = EstablecerUsuarioActual
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual.", vbCritical
        Exit Sub
    End If

    Set cmd = New ADODB.Command
    With cmd
        .ActiveConnection = cnn
        .CommandType = adCmdStoredProc
        
        If idSeguridad = 0 Then ' RUTA DE INSERTAR
            .CommandText = "sp_insertar_seguridad_social"
            .Parameters.Append .CreateParameter("p_id_colaborador", adInteger, adParamInput, , idColaborador)
            .Parameters.Append .CreateParameter("p_cesantias", adVarChar, adParamInput, 100, Nz(Me.txtCesantias, ""))
            .Parameters.Append .CreateParameter("p_pension", adVarChar, adParamInput, 100, Nz(Me.txtPensiones, ""))
            .Parameters.Append .CreateParameter("p_eps", adVarChar, adParamInput, 100, Nz(Me.txtEPS, ""))
            .Parameters.Append .CreateParameter("p_arl", adVarChar, adParamInput, 100, Nz(Me.txtARL, ""))
            .Parameters.Append .CreateParameter("p_riesgo", adVarChar, adParamInput, 5, Nz(Me.cmbRiesgo, ""))
            .Parameters.Append .CreateParameter("p_ccf", adVarChar, adParamInput, 100, Nz(Me.txtCCF, ""))
            .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)
        Else ' RUTA DE ACTUALIZAR
            .CommandText = "sp_actualizar_seguridad_social"
            .Parameters.Append .CreateParameter("p_id_seguridad", adInteger, adParamInput, , idSeguridad)
            .Parameters.Append .CreateParameter("p_cesantias", adVarChar, adParamInput, 100, Nz(Me.txtCesantias, ""))
            .Parameters.Append .CreateParameter("p_pension", adVarChar, adParamInput, 100, Nz(Me.txtPensiones, ""))
            .Parameters.Append .CreateParameter("p_eps", adVarChar, adParamInput, 100, Nz(Me.txtEPS, ""))
            .Parameters.Append .CreateParameter("p_arl", adVarChar, adParamInput, 100, Nz(Me.txtARL, ""))
            .Parameters.Append .CreateParameter("p_riesgo", adVarChar, adParamInput, 5, Nz(Me.cmbRiesgo, ""))
            .Parameters.Append .CreateParameter("p_ccf", adVarChar, adParamInput, 100, Nz(Me.txtCCF, ""))
            .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)
            
            ' Añadir el parámetro de SALIDA
            .Parameters.Append .CreateParameter("p_filas_afectadas", adInteger, adParamOutput)
        End If

        .Execute
        
        ' Leer el valor del parámetro de salida si fue una actualización
        If idSeguridad > 0 Then
            filasAfectadas = .Parameters("p_filas_afectadas").value
            If filasAfectadas = 0 Then
                MsgBox "No se detectaron cambios en los datos de seguridad social.", vbInformation, "Aviso"
                GoTo ExitSub ' Salir para no mostrar el mensaje de "éxito"
            End If
        End If
        
        If cnn.Errors.Count > 0 Then
            MsgBox "Error al guardar los datos: " & cnn.Errors(0).Description, vbCritical
            cnn.Errors.Clear
            GoTo ExitSub
        End If
    End With
    
    If idSeguridad = 0 Then
        MsgBox "Los datos de seguridad social se han guardado correctamente.", vbInformation, "Inserción Exitosa"
    Else
        MsgBox "Los datos de seguridad social se han actualizado correctamente.", vbInformation, "Actualización Exitosa"
    End If
    
    Call CargarDatosSeguridadSocial(idColaborador)

ExitSub:
    On Error Resume Next
    Set cmd = Nothing
    Exit Sub

ErrHandler:
    MsgBox "Error inesperado en el código VBA: " & Err.Description, vbCritical
    Resume ExitSub
End Sub

'==================================================================================================
' FUNCIÓN PRIVADA: Limpiar_Formulario_Completo
'==================================================================================================
Private Sub Limpiar_Formulario_Completo()
    On Error Resume Next ' Evita errores si un control no existe.
    
    ' Limpiar control de ID.
    Me.txtid_colaboradorSeguridadSocial = Null

    ' Limpiar el ListBox.
    Me.lstSeguridadSocialColaborador.RowSource = ""
    
    ' Limpiar los controles de edición.
    Me.txtCesantias = Null
    Me.txtPensiones = Null
    Me.txtEPS = Null
    Me.txtARL = Null
    Me.txtCCF = Null
    Me.cmbRiesgo = Null
    
    On Error GoTo 0
End Sub

'==================================================================================================
' EVENTOS: AfterUpdate para convertir a MAYÚSCULAS
' Función: Se dispara después de editar un campo para convertir su contenido a mayúsculas.
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


