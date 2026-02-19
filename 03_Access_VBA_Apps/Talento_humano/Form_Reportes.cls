VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Reportes"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

' Abrir Reporte de control EMO
Private Sub BTN_ReporteEMO_Click()
    DoCmd.OpenReport "Control_EMO", acViewReport
End Sub

' Exportar Reporte de control EMO
Private Sub btnExportarReporteEMO_Click()
    On Error GoTo ManejoErrores
    
    Dim nombreReporte As String
    Dim rutaExcel As Variant
    Dim xlApp As Object
    Dim xlWorkbook As Object
    Dim xlSheet As Object
    Dim xlRange As Object
    Dim i As Integer
    Dim colIndex As Integer
    Dim diasRestantesCol As Integer
    Dim filtroReporte As String
    
    nombreReporte = "Control_EMO"
    
    ' Verificar si el reporte está abierto
    If Not CurrentProject.AllReports(nombreReporte).IsLoaded Then
        MsgBox "Debe abrir el reporte antes de exportarlo.", vbExclamation, "Reporte no abierto"
        Exit Sub
    End If
    
    ' Capturar el filtro actual del reporte
    filtroReporte = ""
    If Reports(nombreReporte).FilterOn Then
        filtroReporte = Reports(nombreReporte).Filter
    End If
    
    ' Crear instancia de Excel
    Set xlApp = CreateObject("Excel.Application")
    xlApp.Visible = False
    
    ' Mostrar diálogo guardar
    rutaExcel = xlApp.GetSaveAsFilename( _
        InitialFileName:="Reporte_EMO_" & Format(Now(), "yyyymmdd_hhmmss") & ".xlsx", _
        FileFilter:="Archivos de Excel (*.xlsx), *.xlsx", _
        Title:="Guardar Reporte EMO")
    
    ' Verificar si el usuario canceló
    If VarType(rutaExcel) = vbBoolean And rutaExcel = False Then
        xlApp.Quit
        Set xlApp = Nothing
        Exit Sub
    End If
    
    ' Exportar el reporte temporalmente
    DoCmd.OutputTo acOutputReport, nombreReporte, acFormatXLSX, rutaExcel, False
    
    ' Abrir el archivo exportado
    Set xlWorkbook = xlApp.Workbooks.Open(rutaExcel)
    Set xlSheet = xlWorkbook.Sheets(1)
    
    ' Renombrar la hoja a "control_emo"
    xlSheet.Name = "control_emo"
    
    ' ===== FORMATEAR ENCABEZADOS SOLO A1:G1 =====
    Set xlRange = xlSheet.Range("A1:G1")
    With xlRange
        .Font.Bold = True
        .Interior.Color = RGB(0, 51, 102)  ' Azul oscuro
        .Font.Color = RGB(255, 255, 255)  ' Blanco para contraste
        .HorizontalAlignment = -4108  ' Centrado
        .VerticalAlignment = -4108
    End With
    
    ' ===== ENCONTRAR COLUMNA "Dias_Restantes" =====
    diasRestantesCol = 0
    For colIndex = 1 To xlSheet.UsedRange.Columns.Count
        If Trim(xlSheet.Cells(1, colIndex).value) = "Dias_Restantes" Then
            diasRestantesCol = colIndex
            Exit For
        End If
    Next colIndex
    
    ' ===== APLICAR FORMATO CONDICIONAL A DIAS_RESTANTES =====
    If diasRestantesCol > 0 Then
        Dim ultimaFila As Long
        Dim fila As Long
        Dim valor As Variant
        
        ultimaFila = xlSheet.UsedRange.Rows.Count
        
        For fila = 2 To ultimaFila
            valor = xlSheet.Cells(fila, diasRestantesCol).value
            
            If IsNumeric(valor) Then
                If CDbl(valor) >= 30 Then
                    ' Verde
                    xlSheet.Cells(fila, diasRestantesCol).Interior.Color = RGB(0, 176, 80)
                    xlSheet.Cells(fila, diasRestantesCol).Font.Bold = True
                    xlSheet.Cells(fila, diasRestantesCol).Font.Color = RGB(255, 255, 255)
                ElseIf CDbl(valor) >= 1 And CDbl(valor) <= 29 Then
                    ' Amarillo
                    xlSheet.Cells(fila, diasRestantesCol).Interior.Color = RGB(255, 192, 0)
                    xlSheet.Cells(fila, diasRestantesCol).Font.Bold = True
                    xlSheet.Cells(fila, diasRestantesCol).Font.Color = RGB(0, 0, 0)
                Else
                    ' Rojo (menor o igual a 0)
                    xlSheet.Cells(fila, diasRestantesCol).Interior.Color = RGB(255, 0, 0)
                    xlSheet.Cells(fila, diasRestantesCol).Font.Bold = True
                    xlSheet.Cells(fila, diasRestantesCol).Font.Color = RGB(255, 255, 255)
                End If
            End If
        Next fila
    End If
    
    ' ===== AJUSTAR ANCHOS DE COLUMNA =====
    xlSheet.Cells.EntireColumn.AutoFit
    
    ' Establecer ancho mínimo de 12 para todas las columnas
    For colIndex = 1 To xlSheet.UsedRange.Columns.Count
        If xlSheet.Columns(colIndex).ColumnWidth < 12 Then
            xlSheet.Columns(colIndex).ColumnWidth = 12
        End If
    Next colIndex
    
    ' ===== APLICAR AUTOFILTER A LOS ENCABEZADOS =====
    xlSheet.Range("A1:G1").AutoFilter
    
    ' ===== INMOVILIZAR LA FILA 1 =====
    xlSheet.Select
    xlSheet.Range("A2").Select
    xlApp.ActiveWindow.FreezePanes = True
    
    ' Guardar y cerrar
    xlWorkbook.Save
    xlWorkbook.Close False
    xlApp.Quit
    
    ' Limpiar objetos
    Set xlRange = Nothing
    Set xlSheet = Nothing
    Set xlWorkbook = Nothing
    Set xlApp = Nothing
    
    MsgBox "Reporte exportado correctamente a:" & vbCrLf & rutaExcel, vbInformation, "Exportación Completada"
    Exit Sub
    
ManejoErrores:
    ' Manejo de errores corregido
    On Error Resume Next
    If Not xlWorkbook Is Nothing Then xlWorkbook.Close False
    If Not xlApp Is Nothing Then xlApp.Quit
    Set xlRange = Nothing
    Set xlSheet = Nothing
    Set xlWorkbook = Nothing
    Set xlApp = Nothing
    On Error GoTo 0
    MsgBox "Error al exportar: " & Err.Description, vbCritical, "Error"
End Sub

' Función auxiliar para verificar si es número
Private Function IsNumeric(ByVal sValue As Variant) As Boolean
    On Error Resume Next
    IsNumeric = Not IsNull(sValue + 0)
End Function




