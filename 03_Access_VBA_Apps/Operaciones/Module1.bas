Attribute VB_Name = "Module1"
' Módulo: Módulo1

Option Compare Database
Option Explicit

Public Sub LimpiarAperturaOperacion(frm As Form)
    On Error GoTo ManejoErrores
    
    

    Exit Sub

ManejoErrores:
    MsgBox "Error al reiniciar el formulario: " & Err.Description, vbExclamation
End Sub

