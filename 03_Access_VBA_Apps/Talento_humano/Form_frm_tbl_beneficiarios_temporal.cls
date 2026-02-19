VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_frm_tbl_beneficiarios_temporal"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

'==================================================================================================
' --- EVENTO: nombre_AfterUpdate
' --- Función: Convierte el texto a mayúsculas después de que el usuario termina de escribir
'            Se aplica al control nombre en frm_tbl_beneficiarios_temporal
'==================================================================================================

Private Sub nombre_AfterUpdate()
    ' Convertir el texto a mayúsculas solo después de actualizar
    Me.nombre = UCase(Me.nombre)
End Sub
