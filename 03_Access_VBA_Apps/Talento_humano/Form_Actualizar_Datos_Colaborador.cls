VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Actualizar_Datos_Colaborador"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

' VARIABLE PÚBLICA GLOBAL para este formulario
Public idColaboradorActual As Long

'==================================================================================================
' EVENTO: Form_Activate
' Función: Se dispara CADA VEZ que el formulario se activa.
'==================================================================================================
Private Sub Form_Activate()
    Call InicializarFormulario
End Sub

'==================================================================================================
' PROCEDIMIENTO PRIVADO: InicializarFormulario
' Función: Reinicia todos los controles y subformularios a su estado por defecto.
'==================================================================================================
Private Sub InicializarFormulario()
    Dim sql As String

    On Error Resume Next
    
    idColaboradorActual = 0

    Me.txtBuscarColaborador = Null
    Me.txtid_colaborador = Null
    Me.txtid_cc = Null
    Me.txtNombreCompleto = Null

    sql = "SELECT id_colaborador, id_cc, " & _
          "TRIM(primer_nombre & ' ' & segundo_nombre & ' ' & primer_apellido & ' ' & segundo_apellido) AS Nombre " & _
          "FROM vista_colaboradores " & _
          "ORDER BY primer_nombre, primer_apellido;"
    Me.lstColaboradores.RowSource = sql
    Me.lstColaboradores.Requery
    
    ' Limpiar los subformularios
    If Not IsNull(Me.subform_DatosPersonales.Form) Then
        Me.subform_DatosPersonales.Form.LimpiarFormulario
    End If
    
    If Not IsNull(Me.subform_DatosContacto.Form) Then
        Me.subform_DatosContacto.Form.CargarContactosExistentes 0
    End If
    
    If Not IsNull(Me.subform_SeguridadSocial.Form) Then
        Me.subform_SeguridadSocial.Form.CargarDatosSeguridadSocial 0
    End If
    
     If Not IsNull(Me.subform_BeneficiariosColaborador.Form) Then
        Me.subform_BeneficiariosColaborador.Form.CargarDatosBeneficiarios 0
    End If
    
    If Not IsNull(Me.subform_DatosBancarios.Form) Then
        Me.subform_DatosBancarios.Form.CargarDatosBancarios 0
    End If

    
    
    Me.txtBuscarColaborador.SetFocus
    
    On Error GoTo 0
End Sub

'==================================================================================================
' EVENTO: txtBuscarColaborador_Change
'==================================================================================================
Private Sub txtBuscarColaborador_Change()
    Dim sql As String
    Dim filtro As String

    filtro = Replace(Me.txtBuscarColaborador.Text, "'", "''")

    sql = "SELECT id_colaborador, id_cc, " & _
          "TRIM(primer_nombre & ' ' & segundo_nombre & ' ' & primer_apellido & ' ' & segundo_apellido) AS Nombre " & _
          "FROM vista_colaboradores "

    If Len(filtro) > 0 Then
        sql = sql & "WHERE (primer_nombre & ' ' & segundo_nombre & ' ' & primer_apellido & ' ' & segundo_apellido) LIKE '*" & filtro & "*' " & _
                "OR id_cc LIKE '*" & filtro & "*' "
    End If
    
    sql = sql & "ORDER BY primer_nombre, primer_apellido;"

    Me.lstColaboradores.RowSource = sql
End Sub

'==================================================================================================
' EVENTO: lstColaboradores_Click
'==================================================================================================
Private Sub lstColaboradores_Click()
    If Me.lstColaboradores.ListIndex <> -1 Then
        
        Me.txtid_colaborador = Me.lstColaboradores.Column(0)
        Me.txtid_cc = Me.lstColaboradores.Column(1)
        Me.txtNombreCompleto = Me.lstColaboradores.Column(2)
        
        idColaboradorActual = CLng(Me.txtid_colaborador.value)
        
        ' Cargar datos en TODOS los subformularios
        On Error Resume Next
        Me.subform_DatosPersonales.Form.CargarDatos idColaboradorActual
        Me.subform_DatosContacto.Form.CargarContactosExistentes idColaboradorActual
        Me.subform_SeguridadSocial.Form.CargarDatosSeguridadSocial idColaboradorActual
        Me.subform_ContratoColaborador.Form.CargarDatosContrato idColaboradorActual
        Me.subform_BeneficiariosColaborador.Form.CargarDatosBeneficiarios idColaboradorActual
        Me.subform_DatosBancarios.Form.CargarDatosBancarios idColaboradorActual
        Me.subform_TallasDotacion.Form.CargarTallasDotacion idColaboradorActual
        
        On Error GoTo 0

    End If
End Sub

'==================================================================================================
' EVENTO: TabControl_Change (EN EL FORMULARIO PRINCIPAL)
'==================================================================================================
Private Sub TabControl_Change()
    If Nz(idColaboradorActual, 0) = 0 Then
        Exit Sub
    End If
    
    On Error Resume Next
    ' Índice de las pestañas:
    ' 0 = Datos Personales
    ' 1 = Datos de Contacto
    ' 2 = Seguridad Social
    ' 3 = Datos Contrato
    ' 4 = Datos Beneficiario
    ' 5 = Datos Bancarios
    ' 6 = Tallas Dotación
    Select Case Me.TabControl.value
        Case 1 ' Pestaña de Contacto
            Me.subform_DatosContacto.Form.CargarContactosExistentes idColaboradorActual
        Case 2 ' Pestaña de Seguridad Social
            Me.subform_SeguridadSocial.Form.CargarDatosSeguridadSocial idColaboradorActual
        Case 3 ' Pestaña de Datos Contrato (NUEVA)
            Me.subform_ContratoColaborador.Form.CargarDatosContrato idColaboradorActual
        Case 4 ' Pestaña de Beneficiarios
            Me.subform_BeneficiariosColaborador.Form.CargarDatosBeneficiarios idColaboradorActual
        Case 5 ' Pestaña de Datos Bancarios
            Me.subform_DatosBancarios.Form.CargarDatosBancarios idColaboradorActual
        Case 6 ' Pestaña de Tallas Dotación
            Me.subform_TallasDotacion.Form.CargarTallasDotacion idColaboradorActual
            
            
    End Select
    On Error GoTo 0
End Sub




