Attribute VB_Name = "modControlInterfaz"
Option Compare Database
Option Explicit

Public Const acWindowMaximized As Integer = 2


' --- Declaraciones API PÚBLICAS para que sean accesibles desde formularios ---
#If VBA7 Then
    ' ENTORNO VBA7 (Office 2010+) - Compatible con 32 y 64 bits
    Public Declare PtrSafe Function ShowWindow Lib "user32" _
        (ByVal hwnd As LongPtr, ByVal nCmdShow As Long) As Long
    
    Public Declare PtrSafe Function IsWindowVisible Lib "user32" _
        (ByVal hwnd As LongPtr) As Long
    
    Public Declare PtrSafe Function SetWindowLong Lib "user32" Alias "SetWindowLongA" _
        (ByVal hwnd As LongPtr, ByVal nIndex As Long, ByVal dwNewLong As Long) As Long
    
    Public Declare PtrSafe Function GetWindowLong Lib "user32" Alias "GetWindowLongA" _
        (ByVal hwnd As LongPtr, ByVal nIndex As Long) As Long
#Else
    ' ENTORNO anterior a VBA7 (Office 2007 y anteriores)
    Public Declare Function ShowWindow Lib "user32" _
        (ByVal hWnd As Long, ByVal nCmdShow As Long) As Long
    
    Public Declare Function IsWindowVisible Lib "user32" _
        (ByVal hWnd As Long) As Long
    
    Public Declare Function SetWindowLong Lib "user32" Alias "SetWindowLongA" _
        (ByVal hWnd As Long, ByVal nIndex As Long, ByVal dwNewLong As Long) As Long
    
    Public Declare Function GetWindowLong Lib "user32" Alias "GetWindowLongA" _
        (ByVal hWnd As Long, ByVal nIndex As Long) As Long
#End If

' --- Constantes PÚBLICAS ---
Public Const SW_HIDE        As Long = 0
Public Const SW_SHOWNORMAL  As Long = 1
Public Const SW_MINIMIZE    As Long = 2
Public Const SW_MAXIMIZE    As Long = 3
Public Const GWL_EXSTYLE    As Long = -20
Public Const WS_EX_APPWINDOW As Long = &H40000

' ... el resto de tu código permanece igual ...


' Variable de estado
Private m_InterfazMinimizada As Boolean

' Función para configurar interfaz minimalista sin ocultar completamente Access
Public Function ConfigurarInterfaceMinimalSeguro() As Boolean
    On Error GoTo ErrorHandler
    
    ' Configurar elementos de interfaz de Access 2021
    With Application
        ' Ocultar barra de estado (SIEMPRE usar nombres en inglés)
        .SetOption "Show Status Bar", False
        
        ' Ocultar la cinta de opciones (Ribbon)
        DoCmd.ShowToolbar "Ribbon", acToolbarNo
        
        ' Ocultar panel de navegación si está visible
        On Error Resume Next ' Suprimir error si el panel ya está oculto
        DoCmd.NavigateTo "acNavigationCategoryObjectType"
        DoCmd.RunCommand acCmdWindowHide
        On Error GoTo ErrorHandler ' Restaurar manejo de errores
    End With
    
    m_InterfazMinimizada = True
    ConfigurarInterfaceMinimalSeguro = True
    Exit Function
    
ErrorHandler:
    ConfigurarInterfaceMinimalSeguro = False
    MsgBox "Error al configurar la interfaz: " & Err.Description, vbCritical, "Error de Configuración"
End Function

' Función para restaurar interfaz completa
Public Function RestaurarInterfaceCompleta() As Boolean
    On Error GoTo ErrorHandler
    
    With Application
        ' Restaurar barra de estado (SIEMPRE usar nombres en inglés)
        .SetOption "Show Status Bar", True
        DoCmd.ShowToolbar "Ribbon", acToolbarYes
        
        ' Mostrar panel de navegación
        On Error Resume Next
        DoCmd.RunCommand acCmdWindowUnhide
        On Error GoTo ErrorHandler
    End With
    
    m_InterfazMinimizada = False
    RestaurarInterfaceCompleta = True
    Exit Function
    
ErrorHandler:
    RestaurarInterfaceCompleta = False
End Function

' Función para minimizar Access de forma segura manteniendo popups
Public Function MinimizarAccessSeguro() As Boolean
    On Error GoTo ErrorHandler
    
    ' Minimizar la ventana principal de Access
    Call ShowWindow(Application.hWndAccessApp, SW_MINIMIZE)
    
    MinimizarAccessSeguro = True
    Exit Function
    
ErrorHandler:
    MinimizarAccessSeguro = False
End Function

' Propiedad para verificar el estado de la interfaz
Public Property Get InterfazEstaMinimizada() As Boolean
    InterfazEstaMinimizada = m_InterfazMinimizada
End Property


