VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_subform_ContratoColaborador_NUEVO"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

'==================================================================================================
' MÓDULO DEL SUBFORMULARIO: subform_ContratoColaborador (VERSIÓN FINAL LIMPIA)
'==================================================================================================

Private m_idContratoActual As Long

'==================================================================================================
' --- FUNCIONES DE AYUDA PARA CONVERSIÓN SEGURA ---
'==================================================================================================

Private Function SafeCLng(ByVal value As Variant) As Long
    If IsNull(value) Or value = "" Then SafeCLng = 0 Else SafeCLng = CLng(value)
End Function

Private Function SafeCCur(ByVal value As Variant) As Currency
    Dim cleanValue As String
    If IsNull(value) Or value = "" Then
        SafeCCur = 0
    Else
        cleanValue = Replace(Replace(value, "$", ""), ",", "")
        If IsNumeric(cleanValue) Then SafeCCur = CCur(cleanValue) Else SafeCCur = 0
    End If
End Function

' Eliminar registros de Modificacion
Private Sub BTN_EliminarModificacion_Click()
    On Error GoTo ErrHandler
    
    Dim idModificacion As Long
    Dim usuarioActual As String
    Dim respuesta As Integer
    Dim cmd As ADODB.Command
    Dim rst As ADODB.Recordset
    Dim resultadoSP As Integer

    ' --- 1. VALIDACIÓN: Verificar que haya una modificación seleccionada ---
    idModificacion = SafeCLng(Me.txtIdModificacion.value)
    If idModificacion = 0 Then
        MsgBox "Por favor, selecciona una modificación en el listado para eliminar.", vbExclamation, "Validación"
        Me.lstHistorialModificaciones.SetFocus
        Exit Sub
    End If

    ' --- 2. CONFIRMACIÓN DEL USUARIO ---
    respuesta = MsgBox("¿Estás seguro de que deseas eliminar esta modificación?" & vbCrLf & vbCrLf & _
                       "Esta acción no se puede deshacer.", vbQuestion + vbYesNo, "Confirmar Eliminación")
    If respuesta = vbNo Then
        Exit Sub
    End If

    ' --- 3. CONEXIÓN ---
    If Not VerificarYReconectarMySQL() Then Exit Sub
    usuarioActual = EstablecerUsuarioActual
    If usuarioActual = "" Then MsgBox "No se pudo obtener el usuario actual.", vbCritical: Exit Sub

    ' --- 4. CONFIGURACIÓN Y EJECUCIÓN DE ADO ---
    Set cmd = New ADODB.Command
    With cmd
        .ActiveConnection = cnn
        .CommandType = adCmdStoredProc
        .CommandText = "sp_eliminar_modificacion_contrato"
        
        ' Parámetros del SP
        .Parameters.Append .CreateParameter("p_id_modificacion", adInteger, adParamInput, , idModificacion)
        .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)
        
        ' --- EJECUTAR SP Y CAPTURAR RESULTADO ---
        On Error Resume Next
        Set rst = .Execute
        If rst Is Nothing Then
            resultadoSP = 0
        ElseIf Not rst.EOF Then
            resultadoSP = rst!resultado
            rst.Close
        Else
            resultadoSP = 0
        End If
        On Error GoTo ErrHandler
        
        ' --- VERIFICAR ERRORES DE MYSQL ---
        If cnn.Errors.Count > 0 Then MsgBox "Error de MySQL: " & cnn.Errors(0).Description, vbCritical: cnn.Errors.Clear: GoTo ExitSub
    End With

    ' --- 5. INTERPRETAR RESULTADO ---
    Select Case resultadoSP
        Case 1
            MsgBox "La modificación se ha eliminado correctamente.", vbInformation
            Call LimpiarPestanaGestion
            Call CargarPestanaModificaciones(m_idContratoActual)
        Case 0
            MsgBox "No se encontró la modificación solicitada.", vbInformation
        Case -1
            MsgBox "Ocurrió un error en la base de datos.", vbCritical
    End Select

ExitSub:
    Set cmd = Nothing
    If Not rst Is Nothing Then Set rst = Nothing
    Exit Sub
ErrHandler:
    MsgBox "Error inesperado en VBA: " & Err.Description, vbCritical
    Resume ExitSub
End Sub

'==================================================================================================
' --- EVENTOS DEL FORMULARIO Y CONTROLES ---
'==================================================================================================

Private Sub Form_Load()
    Me.cmbNuevoCargo.RowSource = "SELECT id_rol, cargo FROM vista_roles ORDER BY cargo;"
    Call LimpiarFormularioContratoCompleto
End Sub

Private Sub lstHistorialModificaciones_Click()
    Dim selected_id As Long
    If Me.lstHistorialModificaciones.ListIndex = -1 Then Exit Sub
    selected_id = SafeCLng(Me.lstHistorialModificaciones.Column(0))
    If selected_id = 0 Then Exit Sub
    Me.txtIdModificacion = selected_id
    Call CargarDatosModificacionParaEdicion
End Sub

'==================================================================================================
' --- PROCEDIMIENTOS DE CARGA DE DATOS ---
'==================================================================================================

Public Sub CargarDatosContrato(ByVal id_colaborador As Long)
    Dim rst As ADODB.Recordset, sql As String
    Call LimpiarFormularioContratoCompleto
    m_idContratoActual = 0
    If id_colaborador = 0 Then
        Exit Sub
    End If
    If Not VerificarYReconectarMySQL() Then Exit Sub
    sql = "SELECT id_contrato FROM vista_contratos WHERE id_colaborador = " & id_colaborador & " AND contrato_vigente = 1 LIMIT 1;"
    Set rst = New ADODB.Recordset
    rst.Open sql, cnn, adOpenKeyset, adLockOptimistic
    If Not rst.EOF Then m_idContratoActual = rst!id_contrato
    rst.Close
    Set rst = Nothing
    If m_idContratoActual > 0 Then
        Me.txtid_colaboradorContratos = id_colaborador
        Me.txtid_colaboradorModificaciones = id_colaborador
        Me.txtid_contratoModificaciones = m_idContratoActual
        Call CargarPestanaContratoActual(m_idContratoActual)
        Call CargarPestanaModificaciones(m_idContratoActual)
    Else
        Me.txtid_colaboradorModificaciones = id_colaborador
        Me.txtid_colaboradorContratos = id_colaborador
    End If
    Me.Repaint
End Sub

Private Sub CargarPestanaContratoActual(ByVal id_contrato As Long)
    Dim rst As ADODB.Recordset, sql As String
    If Not VerificarYReconectarMySQL() Then Exit Sub
    sql = "SELECT * FROM vista_contratos WHERE id_contrato = " & id_contrato
    Set rst = New ADODB.Recordset
    rst.Open sql, cnn, adOpenKeyset, adLockOptimistic
    If Not rst.EOF Then
        Me.txtid_contrato = rst!id_contrato
        Me.txtid_colaboradorContratos = rst!id_colaborador
        Me.txtFechaIngreso = rst!fecha_ingreso
        Me.cmbTipoContrato = rst!tipo_contrato
        Me.txtFechaTerminacion = rst!termino_meses
        Me.cmbFormaPago = rst!forma_pago
        Me.cmbCentrocosto = rst!id_centro_costo
        Me.txtSalarioBase = rst!salario_base
        Me.txtAuxAlimentacion = rst!aux_alimentacion
        Me.txtAuxTransporte = rst!aux_transporte
        Me.chkSalarioIntegral = rst!salario_integral
        Me.txtRodamiento = rst!rodamiento
        Me.txtTurno = rst!turno
        Me.chkContratoOK = rst!contrato
        Me.txtFechaAfiliacionARL = rst!fecha_afiliacion_arl
        Me.txtFechaAfiliacionEPS = rst!fecha_afiliacion_eps
        Me.txtFechaAfiliacionCCF = rst!fecha_afiliacion_ccf
        Me.txtUltimoOtroSi = rst!num_ultimo_otro_si
        Me.txtPeriodoPrueba = rst!dias_pp
    End If
    rst.Close
    Set rst = Nothing
End Sub

Private Sub CargarPestanaModificaciones(ByVal id_contrato As Long)
    On Error GoTo ErrHandler
    
    Dim sql As String
    
    ' --- Validación básica ---
    If id_contrato <= 0 Then
        Me.lstHistorialModificaciones.RowSource = ""
        Exit Sub
    End If
    
    ' --- Verificar conexión MySQL ---
    If Not VerificarYReconectarMySQL() Then
        MsgBox "No se pudo establecer conexión con la base de datos.", vbCritical
        Exit Sub
    End If
    
    ' --- Construcción de la consulta SQL ---
    sql = "SELECT " & _
          "id_modificacion, " & _
          "id_contrato, " & _
          "fecha_modificacion, " & _
          "tipo_modificacion, " & _
          "observaciones, " & _
          "cambio_salario, " & _
          "cambio_cargo, " & _
          "cambio_fecha_fin, " & _
          "nuevo_aux_alimentacion, " & _
          "nuevo_aux_transporte, " & _
          "nuevo_rodamiento, " & _
          "nuevo_turno " & _
          "FROM vista_contratos_modificaciones " & _
          "WHERE id_contrato = " & id_contrato & " " & _
          "ORDER BY fecha_modificacion DESC;"
    
    ' --- Asignar la consulta al ListBox ---
    Me.lstHistorialModificaciones.RowSource = sql
    Me.lstHistorialModificaciones.Requery
    
    Exit Sub
ErrHandler:
    MsgBox "Error al cargar modificaciones: " & Err.Description, vbCritical
End Sub

Private Sub CargarDatosModificacionParaEdicion()
    With Me.lstHistorialModificaciones
        Me.txtfechaModificacion = .Column(2)
        Me.cmbTipoModificacion = .Column(3)
        Me.txtObservaciones = .Column(4)
        Me.txtNuevoSalario = Nz(.Column(5), Null)
        Me.cmbNuevoCargo = Nz(.Column(6), Null)
        Me.txtNuevaFechaFinalizacion = Nz(.Column(7), Null)
        Me.txtNuevoAuxAlimentacion = Nz(.Column(8), Null)
        Me.txtNuevoAuxTransporte = Nz(.Column(9), Null)
        Me.txtNuevoRodamiento = Nz(.Column(10), Null)
        Me.txtNuevoTurno = Nz(.Column(11), Null)
    End With
End Sub

'==================================================================================================
' --- EVENTOS DE BOTONES ---
'==================================================================================================

Private Sub BTN_BorrarActual_Click()
    Call LimpiarPestanaActual
End Sub

Private Sub BTN_BorrarGestion_Click()
    Call LimpiarPestanaGestion
End Sub

Private Sub BTN_GuardarActual_Click()
    On Error GoTo ErrHandler
    
    Dim cmd As ADODB.Command
    Dim usuarioActual As String
    Dim idColaborador As Long, idContrato As Long
    Dim fechaIngreso As String, tipoContrato As Variant, fechaTerminacion As Variant
    Dim formaPago As String, idCentroCosto As Long, salarioBase As Currency
    Dim auxAlimentacion As Variant, auxTransporte As Variant, salarioIntegral As Integer
    Dim rodamiento As Variant, turno As String, fechaAfiliacionARL As Variant
    Dim fechaAfiliacionEPS As Variant, fechaAfiliacionCCF As Variant
    Dim numUltimoOtroSi As Variant, diasPP As Variant, contrato As Integer
    Dim resultadoSP As Integer
    Dim rst As ADODB.Recordset

    ' --- 1. VALIDACIONES INICIALES ---
    idColaborador = SafeCLng(Me.txtid_colaboradorContratos.value)
    If idColaborador = 0 Then
        MsgBox "El ID del colaborador es obligatorio. Por favor, selecciona un colaborador primero.", vbExclamation, "Validación"
        Me.txtid_colaboradorContratos.SetFocus
        Exit Sub
    End If

    ' --- 2. VALIDAR CAMPOS OBLIGATORIOS ---
    If Not IsDate(Nz(Me.txtFechaIngreso.value, "")) Then
        MsgBox "El campo 'Fecha de Ingreso' es obligatorio y debe ser una fecha válida.", vbExclamation, "Validación"
        Me.txtFechaIngreso.SetFocus
        Exit Sub
    End If
    
    If IsNull(Me.cmbFormaPago.value) Or Me.cmbFormaPago.value = "" Then
        MsgBox "El campo 'Forma de Pago' es obligatorio.", vbExclamation, "Validación"
        Me.cmbFormaPago.SetFocus
        Exit Sub
    End If
    
    If SafeCLng(Me.cmbCentrocosto.value) = 0 Then
        MsgBox "El campo 'Centro de Costo' es obligatorio.", vbExclamation, "Validación"
        Me.cmbCentrocosto.SetFocus
        Exit Sub
    End If
    
    If SafeCCur(Me.txtSalarioBase.value) = 0 Then
        MsgBox "El campo 'Salario Base' es obligatorio y debe ser mayor a 0.", vbExclamation, "Validación"
        Me.txtSalarioBase.SetFocus
        Exit Sub
    End If
    
    If Nz(Me.txtTurno.value, "") = "" Then
        MsgBox "El campo 'Turno' es obligatorio.", vbExclamation, "Validación"
        Me.txtTurno.SetFocus
        Exit Sub
    End If

    ' --- 3. RECOPILAR VALORES DE LOS CONTROLES ---
    fechaIngreso = Format(CDate(Me.txtFechaIngreso.value), "yyyy-mm-dd")
    tipoContrato = Nz(Me.cmbTipoContrato.value, Null)
    
    ' Manejo de fechas NULL
    If IsDate(Nz(Me.txtFechaTerminacion.value, "")) Then
        fechaTerminacion = Format(CDate(Me.txtFechaTerminacion.value), "yyyy-mm-dd")
    Else
        fechaTerminacion = Null
    End If
    
    formaPago = CStr(Me.cmbFormaPago.value)
    idCentroCosto = SafeCLng(Me.cmbCentrocosto.value)
    salarioBase = SafeCCur(Me.txtSalarioBase.value)
    
    ' Limpiar y asignar valores a variables intermedias
    If SafeCCur(Me.txtAuxAlimentacion.value) > 0 Then auxAlimentacion = SafeCCur(Me.txtAuxAlimentacion.value) Else auxAlimentacion = Null
    If SafeCCur(Me.txtAuxTransporte.value) > 0 Then auxTransporte = SafeCCur(Me.txtAuxTransporte.value) Else auxTransporte = Null
    If SafeCCur(Me.txtRodamiento.value) > 0 Then rodamiento = SafeCCur(Me.txtRodamiento.value) Else rodamiento = Null
    
    salarioIntegral = IIf(Me.chkSalarioIntegral.value, 1, 0)
    turno = CStr(Me.txtTurno.value)
    
    ' Manejo de fechas de afiliación (NULL si vacías)
    If IsDate(Nz(Me.txtFechaAfiliacionARL.value, "")) Then
        fechaAfiliacionARL = Format(CDate(Me.txtFechaAfiliacionARL.value), "yyyy-mm-dd")
    Else
        fechaAfiliacionARL = Null
    End If
    
    If IsDate(Nz(Me.txtFechaAfiliacionEPS.value, "")) Then
        fechaAfiliacionEPS = Format(CDate(Me.txtFechaAfiliacionEPS.value), "yyyy-mm-dd")
    Else
        fechaAfiliacionEPS = Null
    End If
    
    If IsDate(Nz(Me.txtFechaAfiliacionCCF.value, "")) Then
        fechaAfiliacionCCF = Format(CDate(Me.txtFechaAfiliacionCCF.value), "yyyy-mm-dd")
    Else
        fechaAfiliacionCCF = Null
    End If
    
    numUltimoOtroSi = Nz(SafeCLng(Me.txtUltimoOtroSi.value), Null)
    diasPP = Nz(SafeCLng(Me.txtPeriodoPrueba.value), Null)
    contrato = IIf(Me.chkContratoOK.value, 1, 0)
    
    ' --- VALIDAR id_contrato: Puede ser Null, vacío o 0 ---
    idContrato = Nz(Me.txtid_contrato.value, 0)
    If IsNull(Me.txtid_contrato.value) Or Me.txtid_contrato.value = "" Then
        idContrato = 0
    Else
        idContrato = SafeCLng(Me.txtid_contrato.value)
    End If

    ' --- 4. CONEXIÓN ---
    If Not VerificarYReconectarMySQL() Then Exit Sub
    usuarioActual = EstablecerUsuarioActual
    If usuarioActual = "" Then MsgBox "No se pudo obtener el usuario actual.", vbCritical: Exit Sub

    ' --- 5. CONFIGURACIÓN Y EJECUCIÓN DE ADO ---
    Set cmd = New ADODB.Command
    With cmd
        .ActiveConnection = cnn
        .CommandType = adCmdStoredProc
        
        ' --- CASO A: ACTUALIZAR CONTRATO EXISTENTE ---
        If idContrato > 0 Then
            .CommandText = "sp_actualizar_contrato"
            .Parameters.Append .CreateParameter("p_id_contrato", adInteger, adParamInput, , idContrato)
            .Parameters.Append .CreateParameter("p_fecha_ingreso", adVarChar, adParamInput, 10, fechaIngreso)
            .Parameters.Append .CreateParameter("p_tipo_contrato", adVarChar, adParamInput, 50, tipoContrato)
            .Parameters.Append .CreateParameter("p_termino_meses", adVarChar, adParamInput, 10, fechaTerminacion)
            .Parameters.Append .CreateParameter("p_forma_pago", adVarChar, adParamInput, 20, formaPago)
            .Parameters.Append .CreateParameter("p_id_centro_costo", adInteger, adParamInput, , idCentroCosto)
            .Parameters.Append .CreateParameter("p_salario_base", adCurrency, adParamInput, , salarioBase)
            .Parameters.Append .CreateParameter("p_aux_alimentacion", adCurrency, adParamInput, , auxAlimentacion)
            .Parameters.Append .CreateParameter("p_aux_transporte", adCurrency, adParamInput, , auxTransporte)
            .Parameters.Append .CreateParameter("p_salario_integral", adTinyInt, adParamInput, , salarioIntegral)
            .Parameters.Append .CreateParameter("p_rodamiento", adCurrency, adParamInput, , rodamiento)
            .Parameters.Append .CreateParameter("p_turno", adVarChar, adParamInput, 50, turno)
            .Parameters.Append .CreateParameter("p_fecha_afiliacion_arl", adVarChar, adParamInput, 10, fechaAfiliacionARL)
            .Parameters.Append .CreateParameter("p_fecha_afiliacion_eps", adVarChar, adParamInput, 10, fechaAfiliacionEPS)
            .Parameters.Append .CreateParameter("p_fecha_afiliacion_ccf", adVarChar, adParamInput, 10, fechaAfiliacionCCF)
            .Parameters.Append .CreateParameter("p_num_ultimo_otro_si", adInteger, adParamInput, , numUltimoOtroSi)
            .Parameters.Append .CreateParameter("p_dias_pp", adInteger, adParamInput, , diasPP)
            .Parameters.Append .CreateParameter("p_contrato", adTinyInt, adParamInput, , contrato)
            .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)
            
            ' --- EJECUTAR SP Y CAPTURAR RESULTADO ---
            On Error Resume Next
            Set rst = .Execute
            If rst Is Nothing Then
                resultadoSP = 0
            ElseIf Not rst.EOF Then
                resultadoSP = rst!resultado
                rst.Close
            Else
                resultadoSP = 0
            End If
            On Error GoTo ErrHandler
            
        ' --- CASO B: CREAR CONTRATO NUEVO ---
        Else
            .CommandText = "sp_insertar_contrato"
            .Parameters.Append .CreateParameter("p_id_colaborador", adInteger, adParamInput, , idColaborador)
            .Parameters.Append .CreateParameter("p_fecha_ingreso", adVarChar, adParamInput, 10, fechaIngreso)
            .Parameters.Append .CreateParameter("p_forma_pago", adVarChar, adParamInput, 20, formaPago)
            .Parameters.Append .CreateParameter("p_id_centro_costo", adInteger, adParamInput, , idCentroCosto)
            .Parameters.Append .CreateParameter("p_salario_base", adCurrency, adParamInput, , salarioBase)
            .Parameters.Append .CreateParameter("p_turno", adVarChar, adParamInput, 50, turno)
            .Parameters.Append .CreateParameter("p_tipo_contrato", adVarChar, adParamInput, 50, tipoContrato)
            .Parameters.Append .CreateParameter("p_termino_meses", adVarChar, adParamInput, 10, fechaTerminacion)
            .Parameters.Append .CreateParameter("p_aux_alimentacion", adCurrency, adParamInput, , auxAlimentacion)
            .Parameters.Append .CreateParameter("p_aux_transporte", adCurrency, adParamInput, , auxTransporte)
            .Parameters.Append .CreateParameter("p_salario_integral", adTinyInt, adParamInput, , salarioIntegral)
            .Parameters.Append .CreateParameter("p_rodamiento", adCurrency, adParamInput, , rodamiento)
            .Parameters.Append .CreateParameter("p_contrato", adTinyInt, adParamInput, , contrato)
            .Parameters.Append .CreateParameter("p_fecha_afiliacion_arl", adVarChar, adParamInput, 10, fechaAfiliacionARL)
            .Parameters.Append .CreateParameter("p_fecha_afiliacion_eps", adVarChar, adParamInput, 10, fechaAfiliacionEPS)
            .Parameters.Append .CreateParameter("p_fecha_afiliacion_ccf", adVarChar, adParamInput, 10, fechaAfiliacionCCF)
            .Parameters.Append .CreateParameter("p_num_ultimo_otro_si", adInteger, adParamInput, , numUltimoOtroSi)
            .Parameters.Append .CreateParameter("p_dias_pp", adInteger, adParamInput, , diasPP)
            .Parameters.Append .CreateParameter("p_contrato_vigente", adTinyInt, adParamInput, , 1)
            .Parameters.Append .CreateParameter("p_usuario", adVarChar, adParamInput, 100, usuarioActual)
            .Parameters.Append .CreateParameter("p_resultado", adInteger, adParamOutput)
            
            ' --- EJECUTAR SP ---
            .Execute
            ' --- LEER EL RESULTADO REAL DEL SP ---
             resultadoSP = .Parameters("p_resultado").value
        End If
        
        ' --- VERIFICAR ERRORES DE MYSQL ---
        If cnn.Errors.Count > 0 Then MsgBox "Error de MySQL: " & cnn.Errors(0).Description, vbCritical: cnn.Errors.Clear: GoTo ExitSub
    End With

    ' --- 6. INTERPRETAR RESULTADO ---
    If idContrato > 0 Then
        ' CASO ACTUALIZACIÓN
        Select Case resultadoSP
            Case 1: MsgBox "El contrato se ha actualizado correctamente.", vbInformation: Call CargarPestanaContratoActual(idContrato)
            Case 0: MsgBox "No se realizaron cambios.", vbInformation
            Case Else: MsgBox "Error al actualizar.", vbCritical
        End Select
    Else
        ' CASO CREACIÓN (NUEVO)
        Select Case resultadoSP
            Case 1
                MsgBox "El contrato se ha creado correctamente.", vbInformation
                Call CargarDatosContrato(idColaborador)
            Case 0
                MsgBox "No se pudo crear: El colaborador ya tiene un contrato vigente activo.", vbExclamation, "Contrato Duplicado"
            Case -1
                MsgBox "Error crítico en la base de datos al intentar guardar.", vbCritical
        End Select
    End If


ExitSub:
    Set cmd = Nothing
    If Not rst Is Nothing Then Set rst = Nothing
    Exit Sub
ErrHandler:
    MsgBox "Error inesperado en VBA: " & Err.Description, vbCritical
    Resume ExitSub
End Sub

' --- EVENTO CLICK DEL BOTÓN GUARDAR (VERSIÓN FINAL REFACTORIZADA) ---
Private Sub BTN_CrearModificacion_Click()
    On Error GoTo ErrHandler
    
    Dim cmd As ADODB.Command, usuarioActual As String, esNuevo As Boolean, fechaParaMySQL As String, resultadoSP As Integer
    Dim pSalario As Variant, pCargo As Variant, pFechaFin As Variant, pAuxAlim As Variant, pAuxTrans As Variant, pRodamiento As Variant

    ' --- 1. Validaciones (VERSIÓN MEJORADA) ---
    If IsNull(Me.cmbTipoModificacion) Then MsgBox "El campo 'Tipo de Modificación' es obligatorio.", vbExclamation: Me.cmbTipoModificacion.SetFocus: Exit Sub
    If Nz(Me.txtObservaciones, "") = "" Then MsgBox "El campo 'Observaciones' es obligatorio.", vbExclamation: Me.txtObservaciones.SetFocus: Exit Sub
    
    ' --- LÓGICA DE VALIDACIÓN CORREGIDA Y FLEXIBLE ---
    If SafeCCur(Me.txtNuevoSalario.value) = 0 And _
       IsNull(Me.cmbNuevoCargo.value) And _
       Not IsDate(Nz(Me.txtNuevaFechaFinalizacion.value, "")) And _
       SafeCCur(Me.txtNuevoAuxAlimentacion.value) = 0 And _
       SafeCCur(Me.txtNuevoAuxTransporte.value) = 0 And _
       SafeCCur(Me.txtNuevoRodamiento.value) = 0 And _
       Nz(Me.txtNuevoTurno.value, "") = "" Then
        
        MsgBox "Debe especificar al menos un cambio para la modificación (nuevo salario, cargo, fecha, auxilio, etc.).", vbExclamation, "Datos Incompletos"
        Exit Sub
    End If
    
    '--- 2. Conexión ---
    If Not VerificarYReconectarMySQL() Then Exit Sub
    usuarioActual = EstablecerUsuarioActual
    If usuarioActual = "" Then MsgBox "No se pudo obtener el usuario actual.", vbCritical: Exit Sub
    
    '--- 3. Preparación Segura de Parámetros ---
    esNuevo = (SafeCLng(Me.txtIdModificacion.value) = 0)
    If esNuevo Then fechaParaMySQL = Format(Date, "yyyy-mm-dd") Else fechaParaMySQL = Format(CDate(Me.txtfechaModificacion.value), "yyyy-mm-dd")
    
    ' Limpiar y asignar valores a variables intermedias
    If SafeCCur(Me.txtNuevoSalario.value) > 0 Then pSalario = SafeCCur(Me.txtNuevoSalario.value) Else pSalario = Null
    If SafeCLng(Me.cmbNuevoCargo.value) > 0 Then pCargo = SafeCLng(Me.cmbNuevoCargo.value) Else pCargo = Null
    If IsDate(Nz(Me.txtNuevaFechaFinalizacion.value, "")) Then pFechaFin = Format(CDate(Me.txtNuevaFechaFinalizacion.value), "yyyy-mm-dd") Else pFechaFin = Null
    If SafeCCur(Me.txtNuevoAuxAlimentacion.value) > 0 Then pAuxAlim = SafeCCur(Me.txtNuevoAuxAlimentacion.value) Else pAuxAlim = Null
    If SafeCCur(Me.txtNuevoAuxTransporte.value) > 0 Then pAuxTrans = SafeCCur(Me.txtNuevoAuxTransporte.value) Else pAuxTrans = Null
    If SafeCCur(Me.txtNuevoRodamiento.value) > 0 Then pRodamiento = SafeCCur(Me.txtNuevoRodamiento.value) Else pRodamiento = Null

    '--- 4. Configuración y Ejecución de ADO ---
    Set cmd = New ADODB.Command
    With cmd
        .ActiveConnection = cnn
        .CommandType = adCmdStoredProc
        
        If esNuevo Then .CommandText = "sp_crear_modificacion_contrato" Else .CommandText = "sp_actualizar_modificacion_contrato"
        If Not esNuevo Then .Parameters.Append .CreateParameter("p_id_modificacion", adInteger, adParamInput, , Me.txtIdModificacion.value)
        
        ' Pasar las variables limpias a los parámetros
        .Parameters.Append .CreateParameter("p_id_contrato", adInteger, adParamInput, , Me.txtid_contratoModificaciones.value)
        .Parameters.Append .CreateParameter("p_fecha_modificacion", adVarChar, adParamInput, 10, fechaParaMySQL)
        .Parameters.Append .CreateParameter("p_tipo_modificacion", adVarChar, adParamInput, 20, CStr(Nz(Me.cmbTipoModificacion.value, "")))
        .Parameters.Append .CreateParameter("p_observaciones", adLongVarChar, adParamInput, 65535, CStr(Nz(Me.txtObservaciones.value, "")))
        .Parameters.Append .CreateParameter("p_nuevo_salario", adCurrency, adParamInput, , pSalario)
        .Parameters.Append .CreateParameter("p_nuevo_cargo", adInteger, adParamInput, , pCargo)
        .Parameters.Append .CreateParameter("p_nueva_fecha_fin", adVarChar, adParamInput, 10, pFechaFin)
        .Parameters.Append .CreateParameter("p_nuevo_aux_alimentacion", adCurrency, adParamInput, , pAuxAlim)
        .Parameters.Append .CreateParameter("p_nuevo_aux_transporte", adCurrency, adParamInput, , pAuxTrans)
        .Parameters.Append .CreateParameter("p_nuevo_rodamiento", adCurrency, adParamInput, , pRodamiento)
        .Parameters.Append .CreateParameter("p_nuevo_turno", adVarChar, adParamInput, 50, Nz(Me.txtNuevoTurno.value, Null))
        .Parameters.Append .CreateParameter("p_usuario_actual", adVarChar, adParamInput, 100, usuarioActual)
        If Not esNuevo Then .Parameters.Append .CreateParameter("p_filas_afectadas", adInteger, adParamOutput)

        .Execute
        If cnn.Errors.Count > 0 Then MsgBox "Error de MySQL: " & cnn.Errors(0).Description, vbCritical: cnn.Errors.Clear: GoTo ExitSub
        If Not esNuevo Then resultadoSP = .Parameters("p_filas_afectadas").value Else resultadoSP = 1
    End With

    '--- 5. Mensajes al usuario ---
    Select Case resultadoSP
        Case 1: MsgBox "La modificación se ha guardado correctamente.", vbInformation: Call LimpiarPestanaGestion: Call CargarPestanaModificaciones(m_idContratoActual)
        Case 0: MsgBox "No se detectaron cambios en los datos. No se realizó ninguna actualización.", vbInformation
        Case -1: MsgBox "Ocurrió un error en la base de datos.", vbCritical
    End Select
    
ExitSub:
    Set cmd = Nothing
    Exit Sub
ErrHandler:
    MsgBox "Error inesperado en VBA: " & Err.Description, vbCritical
    Resume ExitSub
End Sub

'==================================================================================================
' --- RUTINAS DE LIMPIEZA ---
'==================================================================================================

Private Sub LimpiarPestanaActual()
    ' Limpieza de la primera pestaña
End Sub

Private Sub LimpiarPestanaGestion()
    Me.txtIdModificacion = Null: Me.txtfechaModificacion = Null: Me.cmbTipoModificacion = Null
    Me.txtObservaciones = Null: Me.txtNuevoSalario = Null: Me.cmbNuevoCargo = Null
    Me.txtNuevaFechaFinalizacion = Null: Me.txtNuevoAuxAlimentacion = Null
    Me.txtNuevoAuxTransporte = Null: Me.txtNuevoRodamiento = Null: Me.txtNuevoTurno = Null
End Sub

Private Sub LimpiarFormularioContratoCompleto()
    Call LimpiarPestanaActual
    Call LimpiarPestanaGestion
    Me.txtid_contratoModificaciones = Null: Me.txtid_colaboradorModificaciones = Null
    Me.lstHistorialModificaciones.RowSource = ""
End Sub

'==================================================================================================
' EVENTO: TabControlContratos_Change
' Función: Se dispara cuando el usuario cambia entre las dos pestañas del control Tab interno.
' Esto asegura que los datos se recarguen cuando cambias entre "Contrato Actual" y "Gestión de Modificaciones"
'==================================================================================================
Private Sub TabControlContratos_Change()
    If m_idContratoActual = 0 Then Exit Sub

    On Error Resume Next

    Select Case Me.TabControlContratos.value
        Case 0 ' Pestaña "Contrato Actual"
            Call CargarPestanaContratoActual(m_idContratoActual)
        Case 1 ' Pestaña "Gestión de Modificaciones"
            Call CargarPestanaModificaciones(m_idContratoActual)
            Me.lstHistorialModificaciones.Requery
    End Select

    Me.Repaint
    On Error GoTo 0
End Sub

'==================================================================================================
' --- EVENTO: txtTurno_AfterUpdate
' --- Función: Convierte el texto a mayúsculas después de que el usuario termina de escribir
'            Se aplica al control txtTurno en la pestaña "Contrato Actual"
'==================================================================================================

Private Sub txtTurno_AfterUpdate()
    ' Convertir el texto a mayúsculas solo después de actualizar
    Me.txtTurno = UCase(Me.txtTurno)
End Sub

'==================================================================================================
' --- EVENTO: txtNuevoTurno_AfterUpdate
' --- Función: Convierte el texto a mayúsculas después de que el usuario termina de escribir
'            Se aplica al control txtNuevoTurno en la pestaña "Gestión de Modificaciones"
'==================================================================================================

Private Sub txtNuevoTurno_AfterUpdate()
    ' Convertir el texto a mayúsculas solo después de actualizar
    Me.txtNuevoTurno = UCase(Me.txtNuevoTurno)
End Sub

