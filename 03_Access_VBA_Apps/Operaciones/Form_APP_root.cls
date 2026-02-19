VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_APP_root"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub ControlDeNavegacion0_Click()
    ' Usamos esta versión mejorada para que sea más robusto
    On Error Resume Next
    
    Me.SubformularioDeNavegación.Form.Requery
    
    If Err.Number <> 0 Then
        MsgBox "No se pudo actualizar la información. Por favor, intente seleccionar la opción de nuevo.", vbExclamation, "Error de Carga de Datos"
    End If
    
    On Error GoTo 0 ' Restablece el manejo de errores
End Sub

Private Sub Form_Load()
    ' 1. Forzar la maximización de la ventana principal de Access
    ' Usamos SW_MAXIMIZE (valor 3) para asegurar que ocupe toda la pantalla
    Call ShowWindow(Application.hWndAccessApp, SW_MAXIMIZE)
    
    ' 2. Maximizar el formulario DENTRO de la ventana de Access ya maximizada
    DoCmd.Maximize
    
    ' --- Tu código de inicialización existente ---
    If Not VerificarYReconectarMySQL() Then
        MsgBox "Advertencia: No se pudo verificar la conexión con MySQL.", vbExclamation
    End If

    Dim usuarioActual As String
    usuarioActual = EstablecerUsuarioActual()
    'If usuarioActual <> "" Then Me.lblUsuarioSesion.Caption = "Usuario: " & usuarioActual

    If Not InterfazEstaMinimizada Then
        Call ConfigurarInterfaceMinimalSeguro
    End If
End Sub

' Rutina de Cerrado seguro de la aplicación
Private Sub salir_btn_Click()
    On Error Resume Next

    ' Cerrar conexión ADO si está abierta
    If Not cnn Is Nothing Then
        If cnn.State = adStateOpen Then cnn.Close
        Set cnn = Nothing
    End If

    ' Eliminar tablas vinculadas ODBC
    Dim tdf As DAO.TableDef
    For Each tdf In CurrentDb.TableDefs
        If tdf.Connect <> "" Then DoCmd.DeleteObject acTable, tdf.Name
    Next tdf

    ' Vaciar tablas locales
    CurrentDb.Execute "DELETE FROM tbl_ot_temporal", dbFailOnError
    CurrentDb.Execute "DELETE FROM tbl_sesion_actual", dbFailOnError

    ' Limpiar variables globales
    usuario = ""
    password = ""

    ' Restaurar interfaz antes de salir
    Call RestaurarInterfaceCompleta

    ' Cerrar la aplicación Access
    Application.Quit
End Sub

