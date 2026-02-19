Attribute VB_Name = "modUtils"
Option Compare Database
Option Explicit

'---------------------------------------------------------------------------------------
' Procedure : RequeryAllDataControls
' Author    : Juan Saavedra
' Date      : 28-Jul-2025
' Purpose   : Recorre todos los controles de un formulario y sus subformularios
'           : y ejecuta el método .Requery en aquellos que son cuadros de lista
'           : o cuadros combinados para refrescar sus datos.
'---------------------------------------------------------------------------------------
'
Public Sub RequeryAllDataControls(ByVal frm As Form)
    On Error Resume Next ' Ignorar errores si un control no soporta .Requery

    Dim ctl As Control

    ' Recorrer cada control en el formulario principal
    For Each ctl In frm.Controls
        Select Case ctl.ControlType
            ' Refrescar cuadros combinados y cuadros de lista
            Case acComboBox, acListBox
                ctl.Requery

            ' Si el control es un subformulario, llamar a esta misma función recursivamente
            Case acSubform
                ' Llama a la función para el formulario contenido en el control de subformulario
                RequeryAllDataControls ctl.Form
        End Select
    Next ctl

    On Error GoTo 0 ' Restaurar el manejo de errores normal
End Sub


