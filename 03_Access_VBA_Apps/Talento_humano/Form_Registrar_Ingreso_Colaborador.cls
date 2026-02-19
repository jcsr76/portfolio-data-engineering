VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Registrar_Ingreso_Colaborador"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

' ============================================================
' FORMULARIO: Registrar_Ingreso_Colaborador
' ============================================================

' Rutina centralizada para limpiar y deshabilitar el combo de ciudad
Private Sub LimpiarCiudadNacimiento()
    On Error Resume Next
    Me.cmbCiudadNacimiento.RowSource = ""
    Me.cmbCiudadNacimiento = Null
    Me.cmbCiudadNacimiento.Enabled = False
End Sub

Private Sub BTN_Borrar_Click()
    Call RequeryAllDataControls(Me)
    Call Limpiar_Formulario
End Sub

' ============================================================
' EVENTO: Clic en Botón guardar
' ============================================================
Private Sub BTN_Guardar_Click()
    On Error GoTo ErrHandler
    
    Dim ctrl As Control
    Dim camposFaltantes As String
    Dim nombreAmigable As String
    Dim sql As String
    Dim usuarioActual As String

    '------------------------------------------
    ' Validar campos obligatorios
    '------------------------------------------
    Dim listaControles As Variant
    listaControles = Array( _
        "cmbTipoID", "txtNumID", "cmbLugarExpedicion", "txtFechaExpedicion", _
        "txtPrimerNombre", "txtPrimerApellido", "txtSegundoApellido", _
        "cmbFormacionAcademica", "cmbEstadoFormacionAcademica", "txtFechaNacimiento", _
        "cmbSexo", "cmbGrupoSanguineo", "cmbRH", "cmbEstadoCivil", _
        "txtDireccion", "txtBarrio", "cmbEstrato", "cmbPaisNacimiento", _
        "cmbDepartamentoNacimiento", "cmbCiudadNacimiento", "cmbEstatusColaborador", _
        "cmbDepartamento", "cmbCargo", "txtRol", "cmbSede", "txtPlanta", _
        "cmbJefeInmediato", "txtFechaEMO", "txtFechaProxEMO", "txtFechaCarnet", _
        "txtContactoEmergencia", "txtTelefonoContactoEmergencia" _
    )

    Dim i As Integer
    For i = LBound(listaControles) To UBound(listaControles)
        On Error Resume Next
        Set ctrl = Me.Controls(listaControles(i))
        On Error GoTo ErrHandler

        If Not ctrl Is Nothing Then
            ' Nombre amigable (sin el prefijo)
            nombreAmigable = Replace(Replace(Replace(Replace(ctrl.Name, "txt", ""), "cmb", ""), "chk", ""), "_", " ")
            
            ' Verificar si está vacío
            If (ctrl.ControlType = acTextBox And Trim(ctrl.value & "") = "") Or _
               (ctrl.ControlType = acComboBox And (IsNull(ctrl.value) Or Trim(ctrl.value & "") = "")) Then
                camposFaltantes = camposFaltantes & vbCrLf & "- " & nombreAmigable
            End If
        End If
    Next i

    '------------------------------------------
    ' Mostrar mensaje si hay campos vacíos
    '------------------------------------------
    If Len(camposFaltantes) > 0 Then
        MsgBox "Debe diligenciar los siguientes campos antes de guardar:" & vbCrLf & camposFaltantes, vbExclamation, "Campos incompletos"
        Exit Sub
    End If
    
    '------------------------------------------
    ' Verificar que el checkbox esté marcado
    '------------------------------------------
    If Me.chkRutaInduccion.value <> True Then
        MsgBox "Debe confirmar que el colaborador completó la ruta de inducción.", vbExclamation, "Validación"
        Exit Sub
    End If
    
    '------------------------------------------
    ' Verificar conexión MySQL
    '------------------------------------------
    If Not VerificarYReconectarMySQL() Then Exit Sub
    If cnn Is Nothing Then Set cnn = New ADODB.Connection
    If cnn.State <> adStateOpen Then cnn.Open Con

    '------------------------------------------
    ' Obtener usuario actual
    '------------------------------------------
    usuarioActual = EstablecerUsuarioActual
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual. No es posible continuar.", vbCritical
        Exit Sub
    End If
    
    '------------------------------------------
    ' Construir y ejecutar la inserción SQL
    '------------------------------------------
    sql = "CALL insertar_colaborador(" & _
          "'" & Me.cmbTipoID & "','" & Me.txtNumID & "'," & Me.cmbLugarExpedicion & "," & _
          "'" & Format(Nz(Me.txtFechaExpedicion, Date), "yyyy\-mm\-dd") & "','" & Me.txtPrimerNombre & "','" & _
          Me.txtSegundoNombre & "','" & Me.txtPrimerApellido & "','" & Me.txtSegundoApellido & "','" & _
          Me.cmbFormacionAcademica & "','" & Me.cmbEstadoFormacionAcademica & "'," & _
          "'" & Format(Nz(Me.txtFechaNacimiento, Date), "yyyy\-mm\-dd") & "','" & _
          Me.cmbSexo & "','" & Me.cmbGrupoSanguineo & "','" & Me.cmbRH & "','" & _
          Me.cmbEstadoCivil & "','" & Me.txtDireccion & "','" & Me.txtBarrio & "','" & _
          Me.cmbEstrato & "'," & Me.cmbPaisNacimiento & "," & Me.cmbDepartamentoNacimiento & "," & _
          Me.cmbCiudadNacimiento & ",'" & Me.cmbEstatusColaborador & "'," & Me.cmbDepartamento & "," & _
          Me.cmbCargo & "," & Me.cmbSede & ",'" & Me.txtPlanta & "'," & Me.cmbJefeInmediato & "," & _
          "'" & Format(Nz(Me.txtFechaEMO, Date), "yyyy\-mm\-dd") & "','" & _
          Format(Nz(Me.txtFechaProxEMO, Date), "yyyy\-mm\-dd") & "','" & _
          Format(Nz(Me.txtFechaCarnet, Date), "yyyy\-mm\-dd") & "','" & _
          Me.txtContactoEmergencia & "','" & Me.txtTelefonoContactoEmergencia & "'," & _
          IIf(Me.chkRutaInduccion, 1, 0) & ",'" & usuarioActual & "');"

    '------------------------------------------
    ' Ejecutar inserción en MySQL
    '------------------------------------------
    cnn.Execute sql
    
    '------------------------------------------
    ' Mensaje de éxito de operación de inserción
    '------------------------------------------
    MsgBox "Colaborador registrado correctamente.", vbInformation, "Registro exitoso"
    
    '------------------------------------------
    ' Insertar ID en tabla local tbl_ingreso_actual
    '------------------------------------------
    
    ' Limpiar registros COMPLETOS: Solo elimina registros donde TODOS
    ' los campos de seguimiento (Sí/No) sean True
    CurrentDb.Execute "DELETE FROM tbl_ingreso_actual WHERE " & _
        "[contactos_colaboradores] = True AND " & _
        "[seguridad_social] = True AND " & _
        "[contratos] = True AND " & _
        "[beneficiarios] = True AND " & _
        "[cuentas_bancarias_colaboradores] = True AND " & _
        "[tallas_dotacion] = True;"
    
    ' Insertar el nuevo ID de colaborador (txtNumID)
    CurrentDb.Execute "INSERT INTO tbl_ingreso_actual (id_colaborador) VALUES ('" & Me.txtNumID.value & "');"
    
    '------------------------------------------
    ' Refrescar formulario
    '------------------------------------------
    Call RequeryAllDataControls(Me)
    Call Limpiar_Formulario
    
    Exit Sub

'------------------------------------------
' Manejo de errores
'------------------------------------------
ErrHandler:
    ' Capturar diferentes tipos de errores
    Dim errorMsg As String
    errorMsg = Err.Description
    
    ' Verificar si es un error de duplicado
    If InStr(errorMsg, "Ya existe un colaborador") > 0 Or _
       InStr(errorMsg, "Duplicate entry") > 0 Or _
       InStr(errorMsg, "id_cc") > 0 Or _
       InStr(errorMsg, "Unique") > 0 Or _
       Err.Number = -2147467259 Then  ' Error ODBC genérico (80004005)
        
        MsgBox "El número de identificación '" & Me.txtNumID & "' ya está registrado para otro colaborador en el sistema." & vbCrLf & _
               "Use el módulo de actualizaciones si desea modificar sus datos.", vbExclamation, "Colaborador duplicado"
        Me.txtNumID.SetFocus
        
        Call Limpiar_Formulario
        
    Else
        MsgBox "Error al registrar colaborador: " & Err.Number & " - " & errorMsg, vbCritical, "Error"
    End If
End Sub

' Procesos en la carga del formulario
Private Sub Form_Load()
    ' Inicialización de combos dependientes
    Me.cmbDepartamentoNacimiento = Null

    LimpiarCiudadNacimiento
    
    ' ============================================================
    ' Refrescar todos los combos y listas del formulario al cargarlo
    ' ============================================================
    Call RequeryAllDataControls(Me)

End Sub

' ============================================================
' EVENTO: cmbPaisNacimiento_AfterUpdate
' Ajuste: limpiar explícitamente el valor del combo de ciudades
'         antes de recargar su RowSource para evitar que Access
'         recuerde la selección anterior.
' ============================================================
Private Sub cmbPaisNacimiento_AfterUpdate()
    On Error GoTo ErrHandler

    Dim paisSeleccionado As Variant

    paisSeleccionado = Me.cmbPaisNacimiento.Column(1) ' Columna 2 = nombre del país

    ' Si no hay país seleccionado ? limpiar y deshabilitar ciudad
    If IsNull(Me.cmbPaisNacimiento) Or Trim(paisSeleccionado & "") = "" Then
        LimpiarCiudadNacimiento
        Me.cmbDepartamentoNacimiento = Null
        Exit Sub
    End If

    ' --- LIMPIAR EXPLÍCITAMENTE el valor y el RowSource ANTES de recargar ---
    ' esto evita que Access mantenga en memoria la selección anterior
    Me.cmbCiudadNacimiento = Null
    LimpiarCiudadNacimiento

    ' Si hay país seleccionado ? cargar ciudades del país y habilitar el combo
    Me.cmbCiudadNacimiento.RowSource = _
        "SELECT id_ciudad, ciudad, Departamento_Estado, departamento_id " & _
        "FROM vista_ciudades_departamentos " & _
        "WHERE Pais = '" & Replace(paisSeleccionado, "'", "''") & "' " & _
        "ORDER BY ciudad, Pais;"

    Me.cmbCiudadNacimiento.Enabled = True
    Me.cmbCiudadNacimiento.Requery

    ' Limpiar el departamento al cambiar el país
    Me.cmbDepartamentoNacimiento = Null

ExitHandler:
    Exit Sub

ErrHandler:
    MsgBox "Error al cargar las ciudades: " & Err.Description, vbExclamation, "Error"
    Resume ExitHandler
End Sub

' ============================================================
' EVENTO: cmbCiudadNacimiento_AfterUpdate
' ============================================================
Private Sub cmbCiudadNacimiento_AfterUpdate()
    On Error GoTo ErrHandler

    ' Si no hay ciudad seleccionada, limpiar el departamento
    If IsNull(Me.cmbCiudadNacimiento) Or Me.cmbCiudadNacimiento = "" Then
        Me.cmbDepartamentoNacimiento.RowSource = ""
        Me.cmbDepartamentoNacimiento = Null
        Exit Sub
    End If

    ' --------------------------------------------
    ' Obtener el departamento_id de la ciudad seleccionada
    ' (columna 4 del combo)
    ' --------------------------------------------
    Dim deptoID As Long
    deptoID = Nz(Me.cmbCiudadNacimiento.Column(3), 0)

    ' Si hay una ciudad seleccionada, cargar su departamento
    If Not IsNull(Me.cmbCiudadNacimiento) And deptoID <> 0 Then
        Me.cmbDepartamentoNacimiento.RowSource = _
            "SELECT departamento_id, nombre " & _
            "FROM vista_departamentos_col " & _
            "WHERE departamento_id = " & deptoID & ";"

        ' Recargar y seleccionar el departamento correspondiente
        Me.cmbDepartamentoNacimiento.Requery
        Me.cmbDepartamentoNacimiento = deptoID
    Else
        ' Si no hay ciudad válida, limpiar
        Me.cmbDepartamentoNacimiento.RowSource = ""
        Me.cmbDepartamentoNacimiento = Null
    End If

ExitHandler:
    Exit Sub

ErrHandler:
    MsgBox "Error al asignar el departamento: " & Err.Description, vbExclamation, "Error"
    Resume ExitHandler
End Sub

' ============================================================
' EVENTO: cmbCargo_AfterUpdate
'   Se ejecuta al actualizr cmbCargo y actualiza el valor de txtRol.
' ============================================================
Private Sub cmbCargo_AfterUpdate()
    ' Verificar si hay un valor seleccionado
    If Not IsNull(Me.cmbCargo) And Me.cmbCargo.ListIndex <> -1 Then
        ' Colocar el contenido de la columna 3 (rol) en el textbox txtRol
        Me.txtRol = Me.cmbCargo.Column(2)
    Else
        ' Si se borra la selección, limpiar el textbox
        Me.txtRol = Null
    End If
End Sub

' ===============================================
' FUNCIÓN: Limpiar_Formulario
' Descripción: Limpia todos los campos del formulario
' ===============================================
Private Sub Limpiar_Formulario()
    ' Controles tipo ComboBox
    Me.cmbTipoID = Null
    Me.cmbLugarExpedicion = Null
    Me.cmbFormacionAcademica = Null
    Me.cmbEstadoFormacionAcademica = Null
    Me.cmbSexo = Null
    Me.cmbGrupoSanguineo = Null
    Me.cmbRH = Null
    Me.cmbEstadoCivil = Null
    Me.cmbEstrato = Null
    Me.cmbPaisNacimiento = Null
    Me.cmbDepartamentoNacimiento = Null
    Me.cmbCiudadNacimiento = Null
    Me.cmbEstatusColaborador = Null
    Me.cmbDepartamento = Null
    Me.cmbCargo = Null
    Me.cmbSede = Null
    Me.cmbJefeInmediato = Null

    ' Controles tipo TextBox
    Me.txtNumID = ""
    Me.txtFechaExpedicion = ""
    Me.txtPrimerNombre = ""
    Me.txtSegundoNombre = ""
    Me.txtPrimerApellido = ""
    Me.txtSegundoApellido = ""
    Me.txtFechaNacimiento = ""
    Me.txtDireccion = ""
    Me.txtBarrio = ""
    Me.txtRol = ""
    Me.txtFechaEMO = ""
    Me.txtFechaProxEMO = ""
    Me.txtFechaCarnet = ""
    Me.txtContactoEmergencia = ""
    Me.txtTelefonoContactoEmergencia = ""
    Me.txtPlanta = ""

    ' Control tipo CheckBox
    Me.chkRutaInduccion = False
End Sub

'-----------------------------------------------------
' Función auxiliar: convierte texto de Access a formato MySQL
'-----------------------------------------------------
Private Function FormatearFechaMySQL(txt As Variant) As String
    On Error Resume Next
    If IsNull(txt) Or Trim(txt & "") = "" Then
        FormatearFechaMySQL = "NULL"
    ElseIf IsDate(txt) Then
        FormatearFechaMySQL = "'" & Format(CDate(txt), "yyyy-mm-dd") & "'"
    Else
        FormatearFechaMySQL = "NULL"
    End If
    On Error GoTo 0
End Function

'==================================================================================================
' --- EVENTO: txtPrimerNombre_AfterUpdate
' --- Función: Convierte el texto a mayúsculas
'==================================================================================================
Private Sub txtPrimerNombre_AfterUpdate()
    On Error Resume Next
    If Not IsNull(Me.txtPrimerNombre) Then
        Me.txtPrimerNombre = UCase(Me.txtPrimerNombre)
    End If
    On Error GoTo 0
End Sub

'==================================================================================================
' --- EVENTO: txtSegundoNombre_AfterUpdate
' --- Función: Convierte el texto a mayúsculas
'==================================================================================================
Private Sub txtSegundoNombre_AfterUpdate()
    On Error Resume Next
    If Not IsNull(Me.txtSegundoNombre) Then
        Me.txtSegundoNombre = UCase(Me.txtSegundoNombre)
    End If
    On Error GoTo 0
End Sub

'==================================================================================================
' --- EVENTO: txtPrimerApellido_AfterUpdate
' --- Función: Convierte el texto a mayúsculas
'==================================================================================================
Private Sub txtPrimerApellido_AfterUpdate()
    On Error Resume Next
    If Not IsNull(Me.txtPrimerApellido) Then
        Me.txtPrimerApellido = UCase(Me.txtPrimerApellido)
    End If
    On Error GoTo 0
End Sub

'==================================================================================================
' --- EVENTO: txtSegundoApellido_AfterUpdate
' --- Función: Convierte el texto a mayúsculas
'==================================================================================================
Private Sub txtSegundoApellido_AfterUpdate()
    On Error Resume Next
    If Not IsNull(Me.txtSegundoApellido) Then
        Me.txtSegundoApellido = UCase(Me.txtSegundoApellido)
    End If
    On Error GoTo 0
End Sub

'==================================================================================================
' --- EVENTO: txtDireccion_AfterUpdate
' --- Función: Convierte el texto a mayúsculas
'==================================================================================================
Private Sub txtDireccion_AfterUpdate()
    On Error Resume Next
    If Not IsNull(Me.txtDireccion) Then
        Me.txtDireccion = UCase(Me.txtDireccion)
    End If
    On Error GoTo 0
End Sub

'==================================================================================================
' --- EVENTO: txtBarrio_AfterUpdate
' --- Función: Convierte el texto a mayúsculas
'==================================================================================================
Private Sub txtBarrio_AfterUpdate()
    On Error Resume Next
    If Not IsNull(Me.txtBarrio) Then
        Me.txtBarrio = UCase(Me.txtBarrio)
    End If
    On Error GoTo 0
End Sub

'==================================================================================================
' --- EVENTO: txtContactoEmergencia_AfterUpdate
' --- Función: Convierte el texto a mayúsculas
'==================================================================================================
Private Sub txtContactoEmergencia_AfterUpdate()
    On Error Resume Next
    If Not IsNull(Me.txtContactoEmergencia) Then
        Me.txtContactoEmergencia = UCase(Me.txtContactoEmergencia)
    End If
    On Error GoTo 0
End Sub



