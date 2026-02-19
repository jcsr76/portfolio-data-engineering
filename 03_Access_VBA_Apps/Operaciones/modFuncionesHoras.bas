Attribute VB_Name = "modFuncionesHoras"
Option Compare Database

Public Function CalcularHorasReales(horaInicio As Date, horaFinal As Date) As Double
    Dim horasReales As Double
    
    If IsNull(horaInicio) Or IsNull(horaFinal) Then
        CalcularHorasReales = 0
        Exit Function
    End If
    
    If horaFinal <= horaInicio Then
        horasReales = (horaFinal + 1) - horaInicio ' Paso medianoche
    Else
        horasReales = horaFinal - horaInicio
    End If
    
    CalcularHorasReales = horasReales * 24 ' Convertir días a horas
End Function

Public Function CalcularHorasNoOperativas(horasReales As Double) As Double
    If horasReales < 8 Then
        CalcularHorasNoOperativas = 0
    ElseIf horasReales < 9 Then
        CalcularHorasNoOperativas = horasReales - 8
    Else
        CalcularHorasNoOperativas = 1
    End If
End Function

