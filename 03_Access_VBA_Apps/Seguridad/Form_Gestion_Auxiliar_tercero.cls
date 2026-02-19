VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Gestion_Auxiliar_tercero"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

Private Const SQL_BASE_AUXILIARES As String = _
    "SELECT auxiliar_id, ingreso, tipo_id, documento, f_nacim, nombre, g_sang, rh, " & _
    "       direccion, ciudad, n_ciudad, eps, arl, estatus, fecha_nuevo_estatus " & _
    "FROM vista_auxiliares_terceros_seguridad"


' Función de Borrado de campos de formulario


' controles de consulta y Edición
Private Sub LimpiarCampos()
    Me.cmbTipoId = Null
    Me.txtDocumento = Null
    Me.txtFechaNcaimiento = Null
    Me.txtNombreCompleto = Null
    Me.cmbGrupoSanguineo = Null
    Me.cmbRH = Null
    Me.txtDireccion = Null
    Me.cmbCiudad = Null
    Me.cnbEstatusAuxiliar = Null
    Me.txtEPS = Null
    Me.txtARL = Null
    Me.txtauxiliar_id = Null
    
    

' controles de Filtrado
    Me.cmbDocumentoAuxiliar = Null
    Me.cmbCiudadFiltro = Null
    Me.cmbEstatusAuxiliraFiltro = Null
    
End Sub

Private Sub AplicarFiltroAuxiliares()
    Dim sql As String
    Dim condiciones As String
    
    condiciones = ""
    
    '--- Filtro por Ciudad (cmbCiudadFiltro ? campo ciudad) ---
    If Not IsNull(Me.cmbCiudadFiltro) Then
        condiciones = condiciones & " AND ciudad = " & Me.cmbCiudadFiltro
    End If
    
    '--- Filtro por Documento (cmbDocumentoAuxiliar ? campo documento) ---
    If Not IsNull(Me.cmbDocumentoAuxiliar) Then
        condiciones = condiciones & " AND documento = '" & Me.cmbDocumentoAuxiliar & "'"
    End If
    
    '--- Filtro por Estatus (cmbEstatusAuxiliraFiltro ? campo estatus) ---
    If Not IsNull(Me.cmbEstatusAuxiliraFiltro) Then
        condiciones = condiciones & " AND estatus = '" & Me.cmbEstatusAuxiliraFiltro & "'"
    End If
    
    'Construir WHERE si hay condiciones
    If condiciones <> "" Then
        condiciones = " WHERE " & Mid(condiciones, 6)
    End If
    
    sql = SQL_BASE_AUXILIARES & condiciones & " ORDER BY nombre;"
    
    'Aplicar al listbox
    Me.lstDatosAuxiliaresTerceros.RowSource = sql
    Me.lstDatosAuxiliaresTerceros.Requery
    
End Sub

Private Sub BTN_Guardar_Click()
    On Error GoTo ErrHandler

    Dim usuarioActual As String
    Dim sqlCall As String
    Dim sqlResultado As String
    Dim rs As ADODB.Recordset
    Dim resultado As Long
    Dim fechaAux As String
    Dim fechaNac As String
    Dim fechaNuevoEstatus As String
    
    
    '=========================
    ' 0) Validar selección en el listbox
    '=========================
    If IsNull(Me.txtauxiliar_id) Or Me.txtauxiliar_id = "" Then
        MsgBox "Debe seleccionar primero un auxiliar en la lista antes de guardar.", _
               vbExclamation, "Seleccione un registro"
        Exit Sub
    End If
    

    '=========================
    ' 1) Obtener usuario actual
    '=========================
    usuarioActual = EstablecerUsuarioActual()
    If usuarioActual = "" Then
        MsgBox "No se pudo obtener el usuario actual. El registro no se puede actualizar.", vbCritical, "Error"
        Exit Sub
    End If

    '=========================
    ' 2) Verificar/conectar MySQL
    '=========================
    If Not VerificarYReconectarMySQL() Then Exit Sub
    If cnn Is Nothing Then Set cnn = New ADODB.Connection
    If cnn.State <> adStateOpen Then cnn.Open Con

    '=========================
    ' 3) Preparar fechas en formato yyyy-mm-dd (como texto o NULL)
    '=========================
    If IsNull(Me.txtFecha) Or Me.txtFecha = "" Then
        fechaAux = "NULL"
    Else
        fechaAux = "'" & Format(Me.txtFecha, "yyyy-mm-dd") & "'"
    End If

    If IsNull(Me.txtFechaNcaimiento) Or Me.txtFechaNcaimiento = "" Then
        fechaNac = "NULL"
    Else
        fechaNac = "'" & Format(Me.txtFechaNcaimiento, "yyyy-mm-dd") & "'"
    End If

    If IsNull(Me.txtFechaNuevoEstatus) Or Me.txtFechaNuevoEstatus = "" Then
        fechaNuevoEstatus = "NULL"
    Else
        fechaNuevoEstatus = "'" & Format(Me.txtFechaNuevoEstatus, "yyyy-mm-dd") & "'"
    End If

    '=========================
    ' 4) Inicializar variable de salida y llamar al SP
    '   (dos sentencias separadas para evitar errores de sintaxis)
    '=========================
    cnn.Execute "SET @p_resultado := 0;"

    sqlCall = "CALL sp_actualizar_auxiliar_tercero(" & _
              Nz(Me.txtauxiliar_id, 0) & ", " & _
              fechaAux & ", " & _
              "'" & Replace(Nz(Me.cmbTipoId, ""), "'", "''") & "', " & _
              "'" & Replace(Nz(Me.txtDocumento, ""), "'", "''") & "', " & _
              fechaNac & ", " & _
              "'" & Replace(Nz(Me.txtNombreCompleto, ""), "'", "''") & "', " & _
              "'" & Replace(Nz(Me.cmbGrupoSanguineo, ""), "'", "''") & "', " & _
              "'" & Replace(Nz(Me.cmbRH, ""), "'", "''") & "', " & _
              "'" & Replace(Nz(Me.txtDireccion, ""), "'", "''") & "', " & _
              Nz(Me.cmbCiudad, 0) & ", " & _
              "'" & Replace(Nz(Me.txtEPS, ""), "'", "''") & "', " & _
              "'" & Replace(Nz(Me.txtARL, ""), "'", "''") & "', " & _
              "'" & Replace(Nz(Me.cnbEstatusAuxiliar, ""), "'", "''") & "', " & _
              fechaNuevoEstatus & ", " & _
              "'" & Replace(usuarioActual, "'", "''") & "', " & _
              "@p_resultado" & _
              ");"

    cnn.Execute sqlCall

    '=========================
    ' 5) Leer @p_resultado en una segunda sentencia
    '=========================
    sqlResultado = "SELECT @p_resultado AS resultado;"
    Set rs = New ADODB.Recordset
    rs.Open sqlResultado, cnn, adOpenForwardOnly, adLockReadOnly

    If Not rs.EOF Then
        resultado = Nz(rs.Fields("resultado").Value, -1)
    Else
        resultado = -1
    End If

    rs.Close
    Set rs = Nothing

    '=========================
    ' 6) Interpretar resultado
    '=========================
    Select Case resultado
        Case 1
            MsgBox "Datos del auxiliar actualizados correctamente.", vbInformation, "Actualización exitosa"
        Case 0
            MsgBox "No se detectaron cambios en los datos del auxiliar.", vbInformation, "Sin cambios"
        Case -1
            MsgBox "Ocurrió un error al actualizar el auxiliar.", vbCritical, "Error"
        Case Else
            MsgBox "Resultado inesperado del procedimiento (" & resultado & ").", vbExclamation, "Aviso"
    End Select

    LimpiarCampos
    
    CargarComboDocumentoAuxiliar
    
    AplicarFiltroAuxiliares
    
    Exit Sub


ErrHandler:
    MsgBox "Error en BTN_Guardar_Click: " & Err.Description, vbCritical, "Error"
End Sub

' Aplicar filtro de Ciudad
Private Sub cmbCiudadFiltro_AfterUpdate()
    AplicarFiltroAuxiliares
End Sub

' Aplicar filtro de Documento id
Private Sub cmbDocumentoAuxiliar_AfterUpdate()
    AplicarFiltroAuxiliares
End Sub

' Aplicar filtro de Estatus Auxiliar
Private Sub cmbEstatusAuxiliraFiltro_AfterUpdate()
    AplicarFiltroAuxiliares
End Sub


' Botón borrar formulario
Private Sub BTN_Borrar_Click()
    LimpiarCampos
    CargarComboDocumentoAuxiliar
    AplicarFiltroAuxiliares
End Sub

Private Sub CargarComboDocumentoAuxiliar()
    ' Origen de fila del combo de documentos (SELECT DISTINCT desde la vista)
    Me.cmbDocumentoAuxiliar.RowSource = _
        "SELECT DISTINCT documento " & _
        "FROM vista_auxiliares_terceros_seguridad " & _
        "WHERE documento IS NOT NULL " & _
        "ORDER BY documento;"
End Sub


Private Sub Form_Load()
    LimpiarCampos
    
    CargarComboDocumentoAuxiliar
    
    AplicarFiltroAuxiliares   'Carga todos los registros en el listbox
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

' Carga ce datos en los controles para consulta, edicion y actualizacion
Private Sub lstDatosAuxiliaresTerceros_Click()
    ' Verificar que haya un registro seleccionado
    If Me.lstDatosAuxiliaresTerceros.ListIndex = -1 Then Exit Sub
    
    ' Mapear columnas del listbox a controles del formulario
    Me.txtauxiliar_id = Me.lstDatosAuxiliaresTerceros.Column(0)   ' auxiliar_id
    Me.txtFecha = Me.lstDatosAuxiliaresTerceros.Column(1)         ' ingreso
    
    Me.cmbTipoId = Me.lstDatosAuxiliaresTerceros.Column(2)        ' tipo_id
    Me.txtDocumento = Me.lstDatosAuxiliaresTerceros.Column(3)     ' documento
    Me.txtFechaNcaimiento = Me.lstDatosAuxiliaresTerceros.Column(4) ' f_nacim
    Me.txtNombreCompleto = Me.lstDatosAuxiliaresTerceros.Column(5)  ' nombre
    Me.cmbGrupoSanguineo = Me.lstDatosAuxiliaresTerceros.Column(6)  ' g_sang
    Me.cmbRH = Me.lstDatosAuxiliaresTerceros.Column(7)              ' rh
    Me.txtDireccion = Me.lstDatosAuxiliaresTerceros.Column(8)       ' direccion
    Me.cmbCiudad = Me.lstDatosAuxiliaresTerceros.Column(9)          ' ciudad
    Me.txtEPS = Me.lstDatosAuxiliaresTerceros.Column(11)            ' eps
    Me.txtARL = Me.lstDatosAuxiliaresTerceros.Column(12)            ' arl
    Me.cnbEstatusAuxiliar = Me.lstDatosAuxiliaresTerceros.Column(13) ' estatus
End Sub

