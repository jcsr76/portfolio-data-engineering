VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Auxiliar_Tercero"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

' Función de Borrado de campos de formulario
Private Sub LimpiarCampos()
    Me.cmbTipoId = Null
    Me.txtDocumento = Null
    Me.txtFechaNcaimiento = Null
    Me.txtNombreCompleto = Null
    Me.cmbGrupoSanguineo = Null
    Me.cmbRH = Null
    Me.txtDireccion = Null
    Me.cmbCiudad = Null
    Me.txtEPS = Null
    Me.txtARL = Null
End Sub

' Botón borrar formulario
Private Sub BTN_Borrar_Click()
    LimpiarCampos
End Sub

Private Sub BTN_GuardarSolicitud_Click()
    Dim cmd As ADODB.Command
    Dim usuarioActual As String

    ' 1. Verificar la conexión a la base de datos y obtener el usuario actual
    If Not VerificarYReconectarMySQL() Then Exit Sub

    usuarioActual = EstablecerUsuarioActual()
    If usuarioActual = "" Then
        MsgBox "No se pudo definir el usuario para la operación. El proceso se ha cancelado.", vbCritical, "Error de Sesión"
        Exit Sub
    End If

    ' 2. Sección de Validación de Campos Obligatorios del Formulario
    If IsNull(Me.txtFecha.Value) Or Me.txtFecha.Value = "" Then
        MsgBox "El campo 'Fecha' es obligatorio.", vbExclamation, "Validación de Datos"
        Me.txtFecha.SetFocus
        Exit Sub
    End If

    If IsNull(Me.cmbTipoId.Value) Or Me.cmbTipoId.Value = "" Then
        MsgBox "El campo 'Tipo de Identificación' es obligatorio.", vbExclamation, "Validación de Datos"
        Me.cmbTipoId.SetFocus
        Exit Sub
    End If

    If IsNull(Me.txtDocumento.Value) Or Me.txtDocumento.Value = "" Then
        MsgBox "El campo 'Documento' es obligatorio.", vbExclamation, "Validación de Datos"
        Me.txtDocumento.SetFocus
        Exit Sub
    End If

    If IsNull(Me.txtFechaNcaimiento.Value) Or Me.txtFechaNcaimiento.Value = "" Then
        MsgBox "El campo 'Fecha de Nacimiento' es obligatorio.", vbExclamation, "Validación de Datos"
        Me.txtFechaNcaimiento.SetFocus
        Exit Sub
    End If

    If IsNull(Me.txtNombreCompleto.Value) Or Me.txtNombreCompleto.Value = "" Then
        MsgBox "El campo 'Nombre Completo' es obligatorio.", vbExclamation, "Validación de Datos"
        Me.txtNombreCompleto.SetFocus
        Exit Sub
    End If

    If IsNull(Me.cmbGrupoSanguineo.Value) Or Me.cmbGrupoSanguineo.Value = "" Then
        MsgBox "El campo 'Grupo Sanguíneo' es obligatorio.", vbExclamation, "Validación de Datos"
        Me.cmbGrupoSanguineo.SetFocus
        Exit Sub
    End If

    If IsNull(Me.cmbRH.Value) Or Me.cmbRH.Value = "" Then
        MsgBox "El campo 'RH' es obligatorio.", vbExclamation, "Validación de Datos"
        Me.cmbRH.SetFocus
        Exit Sub
    End If

    If IsNull(Me.txtDireccion.Value) Or Me.txtDireccion.Value = "" Then
        MsgBox "El campo 'Dirección' es obligatorio.", vbExclamation, "Validación de Datos"
        Me.txtDireccion.SetFocus
        Exit Sub
    End If
    
    ' Validación para el campo Ciudad
    If IsNull(Me.cmbCiudad.Value) Or Me.cmbCiudad.Value = "" Then
        MsgBox "El campo 'Ciudad' es obligatorio.", vbExclamation, "Validación de Datos"
        Me.cmbCiudad.SetFocus
        Exit Sub
    End If

    If IsNull(Me.txtEPS.Value) Or Me.txtEPS.Value = "" Then
        MsgBox "El campo 'EPS' es obligatorio.", vbExclamation, "Validación de Datos"
        Me.txtEPS.SetFocus
        Exit Sub
    End If

    If IsNull(Me.txtARL.Value) Or Me.txtARL.Value = "" Then
        MsgBox "El campo 'ARL' es obligatorio.", vbExclamation, "Validación de Datos"
        Me.txtARL.SetFocus
        Exit Sub
    End If

    ' 3. Ejecución del Procedimiento Almacenado
    On Error GoTo ErrorHandler

    Set cmd = New ADODB.Command
    With cmd
        .ActiveConnection = cnn ' Usa la conexión global
        .CommandType = adCmdStoredProc
        .CommandText = "Insertar_Auxiliar_Tercero"

        ' Añadir los parámetros
        .Parameters.Append .CreateParameter("p_fecha", adDate, adParamInput, , Me.txtFecha.Value)
        .Parameters.Append .CreateParameter("p_tipo_documento", adVarChar, adParamInput, 10, Me.cmbTipoId.Value)
        .Parameters.Append .CreateParameter("p_documento", adVarChar, adParamInput, 20, Me.txtDocumento.Value)
        .Parameters.Append .CreateParameter("p_fecha_nacimiento", adDate, adParamInput, , Me.txtFechaNcaimiento.Value)
        .Parameters.Append .CreateParameter("p_nombre", adVarChar, adParamInput, 100, Me.txtNombreCompleto.Value)
        .Parameters.Append .CreateParameter("p_grupo_sanguineo", adVarChar, adParamInput, 5, Me.cmbGrupoSanguineo.Value)
        .Parameters.Append .CreateParameter("p_rh", adVarChar, adParamInput, 3, Me.cmbRH.Value)
        .Parameters.Append .CreateParameter("p_direccion", adVarChar, adParamInput, 255, Me.txtDireccion.Value)
        .Parameters.Append .CreateParameter("p_ciudad", adInteger, adParamInput, , Me.cmbCiudad.Value) ' <<< CORREGIDO
        .Parameters.Append .CreateParameter("p_eps", adVarChar, adParamInput, 200, Me.txtEPS.Value)
        .Parameters.Append .CreateParameter("p_arl", adVarChar, adParamInput, 200, Me.txtARL.Value)
        .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)

        ' Ejecutar
        .Execute
    End With

    MsgBox "Solicitud de auxiliar guardada correctamente.", vbInformation, "Éxito"
    LimpiarCampos
    
    ' Forzar la actualizacion de todas las consultas de los controles del formulario
    Call RequeryAllDataControls(Me)

ExitHandler:
    Set cmd = Nothing
    Exit Sub

ErrorHandler:
    If InStr(Err.Description, "Duplicate entry") > 0 And InStr(Err.Description, "for key 'auxiliares_terceros.documento'") > 0 Then
         MsgBox "Ya existe un registro con el mismo tipo y número de documento.", vbExclamation, "Registro Duplicado"
         Me.txtDocumento.SetFocus
    Else
        MsgBox "Error al guardar los datos: " & Err.Description, vbCritical, "Error de Base de Datos"
    End If
    Resume ExitHandler

End Sub

Private Sub Form_Load()
    LimpiarCampos
End Sub

Private Sub txtNombreCompleto_Exit(Cancel As Integer)
    ' Asegurarse que el contenido quede en Mayúsculas
    If Not IsNull(Me.txtNombreCompleto.Value) Then
        Me.txtNombreCompleto.Value = UCase(Me.txtNombreCompleto.Value)
    End If
End Sub

Private Sub txtDireccion_Exit(Cancel As Integer)
    ' Asegurarse que el contenido quede en Mayúsculas
    If Not IsNull(Me.txtDireccion.Value) Then
        Me.txtDireccion.Value = UCase(Me.txtDireccion.Value)
    End If
End Sub

Private Sub txtEPS_Exit(Cancel As Integer)
    ' Asegurarse que el contenido quede en Mayúsculas
    If Not IsNull(Me.txtEPS.Value) Then
        Me.txtEPS.Value = UCase(Me.txtEPS.Value)
    End If
End Sub

Private Sub txtARL_Exit(Cancel As Integer)
    ' Asegurarse que el contenido quede en Mayúsculas
    If Not IsNull(Me.txtARL.Value) Then
        Me.txtARL.Value = UCase(Me.txtARL.Value)
    End If
End Sub
