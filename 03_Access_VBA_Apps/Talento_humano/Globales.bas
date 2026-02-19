Attribute VB_Name = "Globales"
Option Compare Database
Option Explicit

' ==========================================================
' DECLARACIÓN DE SLEEP COMPATIBLE CON OFFICE 32/64 BITS
' ==========================================================
#If VBA7 Then
    Public Declare PtrSafe Sub Sleep Lib "kernel32" (ByVal dwMilliseconds As LongPtr)
#Else
    Public Declare Sub Sleep Lib "kernel32" (ByVal dwMilliseconds As Long)
#End If

' ==========================================================
' VARIABLES GLOBALES
' ==========================================================
Public usuario As String
Public password As String
Public Con As String
Public Con2 As String
Public sql As String
Public cnn As ADODB.Connection      ' Mantener sin New
Public rs As ADODB.Recordset        ' Mantener sin New
Public Ta As TableDef

' ==========================================================
' FUNCIÓN: ESTABLECER VARIABLE DE SESIÓN EN MYSQL
' ==========================================================
Public Function EstablecerUsuarioActual() As String
    On Error GoTo ErrHandler

    If Not VerificarYReconectarMySQL() Then
        MsgBox "No se pudo establecer el usuario porque la conexión con MySQL no está activa.", vbCritical
        Exit Function
    End If

    Dim cmd As Object
    Dim usuario_actual As String
    usuario_actual = DLookup("usuario_actual", "tbl_sesion_actual")

    If usuario_actual = "" Then Exit Function

    Set cmd = CreateObject("ADODB.Command")
    cmd.ActiveConnection = cnn
    cmd.CommandText = "SET @usuario_actual = '" & usuario_actual & "';"
    cmd.Execute

    Set cmd = Nothing
    EstablecerUsuarioActual = usuario_actual
    Exit Function

ErrHandler:
    MsgBox "Error al establecer la variable de sesión: " & Err.Description, vbCritical
    Set cmd = Nothing
End Function

' ==========================================================
' FUNCIÓN GLOBAL DE VERIFICACIÓN Y RECONEXIÓN MYSQL
' Alineada con el formulario Funcional:
' - 8 intentos de ping con 5 s entre cada uno
' - Test adicional TCP con PowerShell (puerto 3306)
' - Solo falla si ambos mecanismos fallan
' - Usa mismos timeout y sleep que el formulario
' ==========================================================
Public Function VerificarYReconectarMySQL() As Boolean
    On Error GoTo ReconectarError

    ' 1 Validar si la conexión ya está activa
    If Not cnn Is Nothing Then
        If cnn.State = adStateOpen Then
            VerificarYReconectarMySQL = True
            Exit Function
        Else
            On Error Resume Next
            cnn.Open
            If cnn.State = adStateOpen Then
                VerificarYReconectarMySQL = True
                Exit Function
            End If
            On Error GoTo ReconectarError
        End If
    End If

    ' 2 Obtener credenciales locales
    Dim rsSesion As DAO.Recordset
    Dim tempUsuario As String, tempPassword As String

    Set rsSesion = CurrentDb.OpenRecordset( _
        "SELECT usuario_actual, contrasena_actual FROM tbl_sesion_actual", dbOpenSnapshot)

    If rsSesion.EOF Then
        MsgBox "No se encontraron datos de sesión. No se puede restablecer la conexión.", vbCritical
        GoTo Limpiar
    End If

    tempUsuario = Nz(rsSesion!usuario_actual, "")
    tempPassword = Nz(rsSesion!contrasena_actual, "")
    rsSesion.Close: Set rsSesion = Nothing

    If tempUsuario = "" Or tempPassword = "" Then
        MsgBox "Las credenciales de sesión están vacías. No se puede reconectar.", vbCritical
        GoTo Limpiar
    End If

    ' 3 PING PREVENTIVO SINCRÓNICO (alineado con formulario Funcional)
    Dim wsh As Object
    Dim rc As Long
    Dim pingOK As Boolean
    Dim tryN As Integer

    Set wsh = CreateObject("WScript.Shell")
    pingOK = False

    For tryN = 1 To 8   ' Hasta 8 intentos -> (8 × 5 s) ˜ 40 s máximo
        rc = wsh.Run("cmd /c ping -n 1 " & ServidorMySQL & " >nul", 0, True)
        If rc = 0 Then
            pingOK = True
            Exit For
        Else
            DoEvents
            Sleep 5000   ' Espera 5 segundos antes del siguiente intento
        End If
    Next tryN

    ' 4 Bloque combinado: Ping preventivo + Test TCP PowerShell
    If Not pingOK Then
        ' Si los pings fallaron, probar el puerto TCP directamente
        If Not TestMySQLPuertoTCP() Then
            MsgBox "No se logró comunicación con el servidor MySQL." & vbCrLf & _
                   "Verifique que la VPN esté conectada y que la ruta hacia " & ServidorMySQL & " esté disponible.", _
                   vbCritical, "Error de Red"
            GoTo Limpiar
        End If
    Else
        ' Incluso si los pings respondieron, validar TCP por seguridad
        If Not TestMySQLPuertoTCP() Then
            MsgBox "El servidor responde ping, pero el puerto 3306 no está accesible." & vbCrLf & _
                   "Espere unos segundos y vuelva a intentar.", vbCritical, "Error de Conexión TCP"
            GoTo Limpiar
        End If
    End If

    ' 5 Reconstruir conexión (alineado con formulario Funcional)
    Set cnn = New ADODB.Connection
    Con = "Driver={MySQL ODBC 9.3 Unicode Driver};" & _
          "Server=" & ServidorMySQL & ";" & _
          "Port=3306;" & _
          "Database=pypdb;" & _
          "UID=" & tempUsuario & ";" & _
          "PWD=" & tempPassword & ";" & _
          "ssl-mode=required;allowPublicKeyRetrieval=true;" & _
          "Option=3;"

    ' Ajustar tiempos de espera recomendados (igual que en el formulario)
    cnn.ConnectionTimeout = 25
    cnn.CommandTimeout = 30

    ' 6 Intentar abrir la conexión ADO
    Sleep 1000
    cnn.Open Con

    ' Validar estado
    If cnn.State = adStateOpen Then
        VerificarYReconectarMySQL = True
    Else
        VerificarYReconectarMySQL = False
    End If

    Exit Function

' 7 Limpieza y manejo de errores
Limpiar:
    VerificarYReconectarMySQL = False
    Exit Function

ReconectarError:
    MsgBox "No se pudo reconectar con el servidor MySQL." & vbCrLf & _
           "Verifique su conexión a la red o VPN.", vbCritical, "Conexión perdida"
    VerificarYReconectarMySQL = False
    Resume Limpiar
End Function

' ==========================================================
' FUNCIÓN AUXILIAR: Obtener ID ciudad estación
' ==========================================================
Public Function ObtenerIdCiudadEstacion() As Variant
    On Error Resume Next
    ObtenerIdCiudadEstacion = Forms!APP_root!SubformularioDeNavegación.Form!cmbEstacion.Column(2)
    If Err.Number <> 0 Then
        ObtenerIdCiudadEstacion = Null
        Err.Clear
    End If
End Function


'------------------------------------------------------------
'  FUNCIÓN GLOBAL: TestMySQLPuertoTCP
'  Usa PowerShell para probar conexión TCP al puerto 3306
'  Retorna True si hay respuesta (exit code 0), False si no.
'------------------------------------------------------------
Public Function TestMySQLPuertoTCP() As Boolean
    On Error GoTo ErrHandler
    Dim wsh As Object
    Dim rc As Long
    Set wsh = CreateObject("WScript.Shell")

    ' Ejecutar PowerShell de forma silenciosa
    ' -Command "Test-NetConnection 10.0.1.122 -Port 3306 | Select-String 'TcpTestSucceeded'"
    rc = wsh.Run("powershell -Command ""$t=Test-NetConnection -ComputerName " & ServidorMySQL & _
                 " -Port 3306; if ($t.TcpTestSucceeded) {exit 0} else {exit 1}""", 0, True)

    TestMySQLPuertoTCP = (rc = 0)
    Exit Function

ErrHandler:
    TestMySQLPuertoTCP = False
End Function

' ==========================================================
' FUNCIÓN: INICIALIZAR OBJETOS GLOBALES
' Debe llamarse al inicio de Form_Open
' ==========================================================
Public Sub InicializarObjetosGlobales()
    On Error Resume Next
    
    ' Cerrar y liberar objetos existentes
    If Not cnn Is Nothing Then
        If cnn.State = adStateOpen Then cnn.Close
        Set cnn = Nothing
    End If
    
    If Not rs Is Nothing Then
        If rs.State = adStateOpen Then rs.Close
        Set rs = Nothing
    End If
    
    ' Crear nuevas instancias
    Set cnn = New ADODB.Connection
    Set rs = New ADODB.Recordset
    
    ' Limpiar variables de cadena
    usuario = ""
    password = ""
    Con = ""
    Con2 = ""
    sql = ""
    
    On Error GoTo 0
End Sub

