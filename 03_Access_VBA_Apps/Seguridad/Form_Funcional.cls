VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Funcional"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

'----------------------------------------------------
'  BOTÓN CANCELAR
'----------------------------------------------------
Private Sub btnCancelar_Click()
    Call ReiniciarFormulario
    ' Asegurarse de que el botón Entrar está al frente y visible
    Me.btnCambiarClave.Visible = False
    Me.btnCancelar.Visible = False
    Me.Entrar.Visible = True
    Me.Entrar.SetFocus
    Me.Repaint

End Sub

'----------------------------------------------------
'  BOTÓN ENTRAR
'----------------------------------------------------
Private Sub Entrar_Click()
    Dim tempUsuario  As String
    Dim tempPassword As String
    Dim rsDept       As ADODB.Recordset
    Dim sqlDept      As String
    Dim deptNumber   As Integer
    
    Dim sqlViews As String
    Dim rsViews As ADODB.Recordset
    Dim rsTest  As ADODB.Recordset
    Dim viewName As String
    Dim Ta      As DAO.TableDef
    Dim TaItem  As DAO.TableDef
    
    Dim mac As String, ip As String, infoRed As String
    Dim sqlLog As String
    
    Dim errorNum As Long
    Dim errorDesc As String
    
    On Error GoTo MostrarError
    
    '------------------------------------------------
    ' 1) Obtener y validar credenciales de la pantalla
    '------------------------------------------------
    tempUsuario = Nz(Me.txtUsuario.Value, "")
    tempPassword = Nz(Me.txtPassword.Value, "")
    
    If Trim(tempUsuario) = "" Or Trim(tempPassword) = "" Then
        MsgBox "Debe ingresar usuario y clave.", vbExclamation, "Aviso"
        Exit Sub
    End If
    
    ' Sanitizar apóstrofes para evitar errores SQL
    tempUsuario = Replace(tempUsuario, "'", "''")
    tempPassword = Replace(tempPassword, "'", "''")
    
    '------------------------------------------------
    ' 2) GUARDAR CREDENCIALES INMEDIATAMENTE (antes de intentar conexión)
    '------------------------------------------------
    infoRed = ObtenerMACeIP()
    mac = Split(infoRed, "|")(0)
    ip = Split(infoRed, "|")(1)
    
    CurrentDb.Execute "DELETE FROM tbl_sesion_actual"
    CurrentDb.Execute "INSERT INTO tbl_sesion_actual " & _
       "(usuario_actual, contrasena_actual, ip_actual, mac_actual) VALUES " & _
       "('" & tempUsuario & "', '" & tempPassword & "', '" & ip & "', '" & mac & "')"
    

    '------------------------------------------------
    ' 3) Cadenas de conexión (VERSIÓN CORREGIDA Y FINAL)
    '------------------------------------------------
Con = "Driver={MySQL ODBC 9.3 Unicode Driver};" & _
      "Server=" & ServidorMySQL & ";" & _
      "Port=3306;" & _
      "Database=pypdb;" & _
      "UID=" & tempUsuario & ";" & _
      "PWD=" & tempPassword & ";" & _
      "ssl-mode=required;allowPublicKeyRetrieval=true;" & _
      "Option=3;"

Con2 = "ODBC;DRIVER={MySQL ODBC 9.3 Unicode Driver};" & _
       "Server=" & ServidorMySQL & ";" & _
       "Port=3306;" & _
       "Database=pypdb;" & _
       "UID=" & tempUsuario & ";" & _
       "PWD=" & tempPassword & ";" & _
       "ssl-mode=required;allowPublicKeyRetrieval=true;" & _
       "Option=3;"


    
    '------------------------------------------------
    ' 4) Intentar conexión ADO
    '------------------------------------------------
    On Error GoTo ManejoErrorConPassword
    
    cnn.ConnectionString = Con
    cnn.Open
    
    On Error GoTo MostrarError  ' Restaurar manejador después de abrir
    
sqlDept = "SELECT departamento, base_id, bases FROM vista_usuarios_departamentos " & _
          "WHERE usuario = '" & tempUsuario & "';"

    
    Set rsDept = New ADODB.Recordset
    rsDept.Open sqlDept, cnn, adOpenStatic, adLockReadOnly
    
    If rsDept.EOF Then
        MsgBox "Usuario no encontrado en la vista de departamentos.", vbExclamation, "Acceso Denegado"
        GoTo ManejoErrorConexion
    Else
        deptNumber = rsDept!departamento
        If deptNumber <> 6 Then
            MsgBox "Usuario no autorizado para este terminal.", vbExclamation, "Acceso Denegado"
            GoTo ManejoErrorConexion
        End If
        
        Dim baseUsuario As Variant
        Dim nombreBase As String
        baseUsuario = Nz(rsDept!base_id, 0)
        nombreBase = Nz(rsDept!bases, "")
        
        CurrentDb.Execute "UPDATE tbl_sesion_actual SET base_actual = " & baseUsuario & ", nombre_base = '" & Replace(nombreBase, "'", "''") & "'"
    End If
    rsDept.Close
    
    '------------------------------------------------
    ' 6) Guardar credenciales globales
    '------------------------------------------------
    usuario = tempUsuario
    password = tempPassword
    
    '------------------------------------------------
    ' 7) Vincular solo vistas con permiso
    '------------------------------------------------
    sqlViews = "SHOW FULL TABLES FROM pypdb WHERE TABLE_TYPE='VIEW';"
    Set rsViews = New ADODB.Recordset
    rsViews.Open sqlViews, cnn, adOpenDynamic, adLockOptimistic
    
    Do While Not rsViews.EOF
        viewName = rsViews.Fields("Tables_in_pypdb").Value
        
        For Each TaItem In CurrentDb.TableDefs
            If TaItem.Name = viewName Then
                CurrentDb.TableDefs.Delete viewName
                Exit For
            End If
        Next
        
        On Error Resume Next
        Set rsTest = New ADODB.Recordset
        rsTest.Open "SELECT 1 FROM " & viewName & " LIMIT 1", cnn, adOpenStatic, adLockReadOnly
        If Err.Number = 0 Then
            Set Ta = CurrentDb.CreateTableDef(viewName, dbAttachSavePWD, viewName, Con2)
            CurrentDb.TableDefs.Append Ta
            rsTest.Close
        End If
        Err.Clear: On Error GoTo MostrarError
        
        rsViews.MoveNext
    Loop
    rsViews.Close
    
    '------------------------------------------------
    ' 8) Registrar log de conexión
    '------------------------------------------------
    On Error GoTo ErrLogConexion
    
    sqlLog = "CALL registrar_log_conexion('" & tempUsuario & "','" & ip & "','" & mac & "');"
    
    If cnn.State <> adStateOpen Then
        cnn.Open
    End If
    
    cnn.Execute sqlLog
    On Error GoTo MostrarError
    
    '------------------------------------------------
    ' 9) Establecer la variable de sesión y aplicar interfaz minimalista
    '------------------------------------------------
    Call EstablecerUsuarioActual
    Call MinimizarAccessSeguro
    Call ConfigurarInterfaceMinimalSeguro
    
    '------------------------------------------------
    ' 10) Abrir formulario principal y cerrar éste
    '------------------------------------------------
    If CurrentProject.AllForms("App_root").IsLoaded Then
        DoCmd.Close acForm, Me.Name
        Exit Sub
    End If
    
    Me.Entrar.Enabled = False
    Me.txtUsuario.Enabled = False
    Me.txtPassword.Enabled = False
    Me.btnCancelar.Enabled = False
    Me.btnSalir.Enabled = False
    DoEvents
    
    DoCmd.OpenForm "App_root", acNormal
    DoCmd.Close acForm, Me.Name
    cnn.Close
    Exit Sub

ManejoErrorConPassword:
    errorNum = Err.Number
    errorDesc = Err.Description

    ' Detecta error por contraseña expirada
    If errorNum = -2147217843 Or _
       errorNum = 1820 Or _
       errorNum = 1862 Or _
       InStr(LCase(errorDesc), "your password has expired") > 0 Or _
       InStr(LCase(errorDesc), "reset your password") > 0 Or _
       InStr(LCase(errorDesc), "1820") > 0 Or _
       InStr(LCase(errorDesc), "1862") > 0 Or _
       InStr(LCase(errorDesc), "expired") > 0 Or _
       InStr(LCase(errorDesc), "must change") > 0 Or _
       InStr(LCase(errorDesc), "supports expired") > 0 Then
        
        Call MostrarPanelCambioClave
        Exit Sub
        
    ' Detecta error de credenciales incorrectas
    ElseIf InStr(LCase(errorDesc), "access denied for user") > 0 Then
        CurrentDb.Execute "DELETE FROM tbl_sesion_actual"
        MsgBox "Usuario y/o Contraseña equivocado(s), por favor intente nuevamente.", vbExclamation, "Acceso Denegado"
        ReiniciarFormulario
        Exit Sub
    ' ***** NUEVO BLOQUE PARA MANEJAR ERROR DE CONEXIÓN *****
    ElseIf errorNum = -2147467259 Or InStr(LCase(errorDesc), "can't connect to mysql server") > 0 Then
        CurrentDb.Execute "DELETE FROM tbl_sesion_actual"
        MsgBox "No se pudo establecer la conexión con el servidor MySQL." & vbCrLf & vbCrLf & _
               "Por favor, revise su conexión a internet y verifique que la VPN esté conectada.", vbCritical, "Error de Conexión"
        ReiniciarFormulario
        Exit Sub
    ' ***** FIN DEL NUEVO BLOQUE *****
        
    Else ' Otros errores no manejados específicamente
        CurrentDb.Execute "DELETE FROM tbl_sesion_actual"
        MsgBox "Error: " & errorNum & vbCrLf & errorDesc, vbCritical, "Error de conexión"
        ReiniciarFormulario
        Exit Sub
    End If

MostrarError:
    CurrentDb.Execute "DELETE FROM tbl_sesion_actual"
    MsgBox "Error: " & Err.Number & vbCrLf & Err.Description, vbCritical, "Error detallado de conexión"
    ReiniciarFormulario
    Exit Sub

ErrLogConexion:
    MsgBox "Error al registrar log de conexión: " & Err.Description, vbExclamation, "Error en log"
    Resume Next

ManejoErrorConexion:
    CurrentDb.Execute "DELETE FROM tbl_sesion_actual"
    ReiniciarFormulario
    Exit Sub
End Sub

'----------------------------------------------------
' REINICIAR FORMULARIO
'----------------------------------------------------
Private Sub ReiniciarFormulario()
    On Error Resume Next ' Mantenemos el manejo de errores por si algún objeto ya es nulo
    
    ' Cierra y libera el objeto Recordset si existe
    If Not rs Is Nothing Then
        If rs.State <> adStateClosed Then rs.Close
        Set rs = Nothing
    End If
    
    ' Cierra y destruye completamente el objeto Connection si existe
    If Not cnn Is Nothing Then
        If cnn.State <> adStateClosed Then cnn.Close
        Set cnn = Nothing ' <-- ESTE ES EL CAMBIO MÁS IMPORTANTE
    End If
    
    ' Restablece la visibilidad de los controles de login
    Me.txtUsuario.Visible = True
    Me.txtPassword.Visible = True
    Me.Entrar.Visible = True
    Me.btnSalir.Visible = True

    ' Oculta los controles de cambio de clave
    Me.txtClaveActual.Visible = False
    Me.txtClaveNueva.Visible = False
    Me.txtConfirmarClaveNueva.Visible = False
    Me.btnCambiarClave.Visible = False
    Me.btnCancelar.Visible = False
    
    ' Limpia variables y controles
    usuario = "": password = "": Con = "": Con2 = "": sql = ""
    Me.txtUsuario.Value = ""
    Me.txtPassword.Value = ""
    Me.txtUsuario.SetFocus
End Sub


'----------------------------
' Función para obtener MAC e IP (Versión Corregida y Robusta)
'----------------------------
Private Function ObtenerMACeIP() As String
    Dim objWMIService As Object
    Dim colItems As Object
    Dim objItem As Object
    Dim ip As String
    Dim mac As String
    Dim arrIP As Variant

    On Error GoTo ErrHandler

    ' Conectarse al servicio WMI del equipo local
    Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")

    ' Obtener los adaptadores de red habilitados
    Set colItems = objWMIService.ExecQuery("SELECT * FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = True")

    ' Iterar sobre los adaptadores para obtener MAC e IP
    For Each objItem In colItems
        ' Asignar la MAC si aún no la tenemos
        If mac = "" And Not IsNull(objItem.MACAddress) Then
            mac = objItem.MACAddress
        End If
        
        ' Asignar la IP si aún no la tenemos
        If ip = "" And Not IsNull(objItem.IPAddress) Then
            arrIP = objItem.IPAddress
            ' Verificar si es una matriz y si contiene al menos un elemento
            If IsArray(arrIP) Then
                If UBound(arrIP) >= 0 Then
                    ' Priorizar direcciones IPv4 (que contienen puntos)
                    Dim tempIP As Variant
                    For Each tempIP In arrIP
                        If InStr(1, tempIP, ".") > 0 Then
                            ip = tempIP
                            Exit For ' Salir del bucle interno una vez encontrada una IPv4
                        End If
                    Next
                End If
            End If
        End If
        
        ' Si ya encontramos ambas, salimos del bucle principal
        If mac <> "" And ip <> "" Then Exit For
    Next

    If mac = "" Then mac = "MAC no encontrada"
    If ip = "" Then ip = "IP no encontrada"

    ObtenerMACeIP = mac & "|" & ip
    Exit Function

ErrHandler:
    ObtenerMACeIP = "Error|Error"
End Function

'----------------------------------------------------
' FORM_LOAD - Con minimización de Access desde el inicio
'----------------------------------------------------
Private Sub Form_Load()
    On Error Resume Next
    
    Me.txtUsuario.Visible = True
    Me.txtPassword.Visible = True
    Me.Entrar.Visible = True
    Me.btnSalir.Visible = True
    
    If Not cnn Is Nothing Then
        If cnn.State = adStateOpen Then cnn.Close
        Set cnn = Nothing
    End If
    
    ' Eliminar tablas vinculadas ODBC
    Dim tdf As DAO.TableDef
    For Each tdf In CurrentDb.TableDefs
        If tdf.Connect <> "" Then DoCmd.DeleteObject acTable, tdf.Name
    Next
    
    ' Vaciar tablas locales
    CurrentDb.Execute "DELETE FROM tbl_ot_temporal", dbFailOnError
    CurrentDb.Execute "DELETE FROM tbl_sesion_actual", dbFailOnError
    
    usuario = "": password = ""
    
    Me.txtClaveActual.Visible = False
    Me.txtClaveNueva.Visible = False
    Me.txtConfirmarClaveNueva.Visible = False
    Me.btnCambiarClave.Visible = False
    Me.btnCancelar.Visible = False
    
End Sub

'----------------------------------------------------
' BOTÓN SALIR
'----------------------------------------------------
Private Sub btnSalir_Click()
    On Error Resume Next
    
    If Not cnn Is Nothing Then
        If cnn.State = adStateOpen Then cnn.Close
        Set cnn = Nothing
    End If
    
    ' Eliminar enlaces ODBC
    Dim tdf As DAO.TableDef
    For Each tdf In CurrentDb.TableDefs
        If tdf.Connect <> "" Then DoCmd.DeleteObject acTable, tdf.Name
    Next
    
    CurrentDb.Execute "DELETE FROM tbl_ot_temporal", dbFailOnError
    CurrentDb.Execute "DELETE FROM tbl_sesion_actual", dbFailOnError
    
    usuario = "": password = ""
    
    ' ? Restaurar interfaz completa antes de salir
    Call RestaurarInterfaceCompleta
    
    Application.Quit

End Sub

'----------------------------------------------------
' BOTÓN CAMBIAR CLAVE (VERSIÓN DIRECTA Y FINAL)
'----------------------------------------------------
Private Sub btnCambiarClave_Click()
    Dim nuevaClave As String
    Dim confirmarClave As String
    Dim claveActualIntento As String
    Dim rsSesion As DAO.Recordset
    Dim usuarioActual As String
    Dim contrasenaActual As String

    ' Obtener usuario y contraseña actuales desde tbl_sesion_actual
    Set rsSesion = CurrentDb.OpenRecordset("SELECT usuario_actual, contrasena_actual FROM tbl_sesion_actual", dbOpenSnapshot)
    If Not rsSesion.EOF Then
        usuarioActual = rsSesion!usuario_actual
        contrasenaActual = rsSesion!contrasena_actual
    Else
        MsgBox "No existe una sesión activa. Reinicie el formulario.", vbExclamation
        rsSesion.Close
        Exit Sub
    End If
    rsSesion.Close

    ' Obtener valores desde los controles del formulario
    claveActualIntento = Nz(Me.txtClaveActual.Value, "")
    nuevaClave = Nz(Me.txtClaveNueva.Value, "")
    confirmarClave = Nz(Me.txtConfirmarClaveNueva.Value, "")

    ' Validaciones básicas
    If Trim(claveActualIntento) = "" Or Trim(nuevaClave) = "" Or Trim(confirmarClave) = "" Then
        MsgBox "Debe completar todos los campos.", vbExclamation
        Exit Sub
    End If

    If nuevaClave <> confirmarClave Then
        MsgBox "Las contraseñas nuevas no coinciden.", vbExclamation
        BorrarPanelCambioClave
        Exit Sub
    End If

    If claveActualIntento <> contrasenaActual Then
        MsgBox "La contraseña actual no coincide con la guardada. Vuelva a intentarlo.", vbExclamation
        BorrarPanelCambioClave
        Exit Sub
    End If

    On Error GoTo ManejoError

    Dim cnnCambio As New ADODB.Connection
    Dim conCambio As String
    
    ' Cadena de conexión para MySQL 8.4 con sandbox mode
    conCambio = "Driver={MySQL ODBC 9.3 Unicode Driver};" & _
                "Server=" & ServidorMySQL & ";" & _
                "User=" & usuarioActual & ";" & _
                "Password=" & contrasenaActual & ";" & _
                "Option=3;SSLMode=REQUIRED;" & _
                "can_handle_exp_pwd=1;" & _
                "initstmt=SET PASSWORD = '" & nuevaClave & "';"

    ' Intentar conexión - esto ejecutará automáticamente el cambio de contraseña
    cnnCambio.Open conCambio
    cnnCambio.Close

    ' Actualizar la contraseña local en Access
    CurrentDb.Execute "UPDATE tbl_sesion_actual SET contrasena_actual = '" & nuevaClave & "' WHERE usuario_actual = '" & usuarioActual & "'"

    MsgBox "Contraseña cambiada correctamente. Por favor inicie sesión nuevamente.", vbInformation
    Call ReiniciarFormulario
    
    ' Asegurarse de que el botón Entrar está al frente y visible
    Me.btnCambiarClave.Visible = False
    Me.btnCancelar.Visible = False
    Me.Entrar.Visible = True
    Me.Entrar.SetFocus
    Me.Repaint

    Exit Sub

ManejoError:
    ' Detectar error específico de política de contraseñas
    If Err.Number = -2147467259 Then
        If InStr(LCase(Err.Description), "password does not satisfy") > 0 Or _
           InStr(LCase(Err.Description), "policy requirements") > 0 Then
            
            ' Mensaje personalizado para política de contraseñas
            Dim mensajePolitica As String
            mensajePolitica = "La nueva contraseña no cumple con las políticas de seguridad." & vbCrLf & vbCrLf & _
                             "Las políticas de contraseña son:" & vbCrLf & _
                             "• Contraseña mínimo 8 caracteres" & vbCrLf & _
                             "• Debe tener mayúsculas y minúsculas" & vbCrLf & _
                             "• Debe tener al menos 1 número" & vbCrLf & _
                             "• Debe tener al menos 1 caracter especial" & vbCrLf & _
                             "• No puede contener el nombre de usuario" & vbCrLf & vbCrLf & _
                             "Por favor, intente con una contraseña que cumpla estos requisitos."
            
            MsgBox mensajePolitica, vbExclamation, "Política de Contraseñas"
            BorrarPanelCambioClave
            Exit Sub
        End If
    End If
    
    ' Para otros errores, mostrar mensaje original
    MsgBox "Error cambiando contraseña: " & Err.Description & vbCrLf & _
           "Código: " & Err.Number, vbCritical, "Error"
    If cnnCambio.State <> 0 Then cnnCambio.Close
    BorrarPanelCambioClave
End Sub

'----------------------------------------------------
' Función pasar Formulario a modo cambiar contraseña
'----------------------------------------------------
Private Sub MostrarPanelCambioClave()
    On Error Resume Next
    
    ' Mostrar controles de cambio PRIMERO
    Me.txtClaveActual.Visible = True
    Me.txtClaveNueva.Visible = True
    Me.txtConfirmarClaveNueva.Visible = True
    Me.btnCambiarClave.Visible = True
    Me.btnCancelar.Visible = True
    
    ' Limpiar valores
    Me.txtClaveActual.Value = ""
    Me.txtClaveNueva.Value = ""
    Me.txtConfirmarClaveNueva.Value = ""
    
    ' Cambiar foco ANTES de ocultar el botón que tiene el foco
    Me.txtClaveActual.SetFocus
    
    ' Ahora ocultar controles de login
    Me.txtUsuario.Visible = False
    Me.txtPassword.Visible = False
    Me.Entrar.Visible = False
    Me.btnSalir.Visible = False
    
    On Error GoTo 0
    
     ' Mensaje con información de expiración Y políticas de contraseña
    Dim mensajeExpiracion As String
    mensajeExpiracion = "Su contraseña ha expirado. Por favor, cambie la clave para continuar." & vbCrLf & vbCrLf & _
                       "Las políticas de contraseña son las siguientes:" & vbCrLf & _
                       "• Contraseña mínimo 8 caracteres" & vbCrLf & _
                       "• Debe tener mayúsculas y minúsculas" & vbCrLf & _
                       "• Debe tener al menos 1 número" & vbCrLf & _
                       "• Debe tener al menos 1 caracter especial" & vbCrLf & _
                       "• No puede contener el nombre de usuario"
    
    MsgBox mensajeExpiracion, vbInformation, "Cambio de Contraseña Requerido"
End Sub

Private Sub BorrarPanelCambioClave()
   Me.txtClaveActual.Value = ""
   Me.txtClaveNueva.Value = ""
   Me.txtConfirmarClaveNueva.Value = ""
   Me.txtClaveActual.SetFocus

End Sub



