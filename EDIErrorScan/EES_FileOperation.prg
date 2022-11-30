//////////////////////////////////////////////////////////////////////
//
//  EES_FileOperation.PRG
//
//  Copyright:
//      stratEDI GmbH, (c) 2022. Alle Rechte vorbehalten.
//
//  Inhalt:
//      Enthalten sind Funktionen und Prozeduren die das Handling mit den
//      verschiedenen Dateien (Eingangsdatei, Fehlerprotokoll, Config uÄ)
//      ubernehmen
//
//////////////////////////////////////////////////////////////////////
#include "Gra.ch"
#include "Xbp.ch"
#include "Common.ch"
#include "Appevent.ch"
#include "Font.ch"
#include "EES.ch"

#pragma library( "XPPUI2.LIB" )
#pragma library( "ADAC20B.LIB" )
#pragma library( "xbtbase1.lib")

#pragma library ("E:\xbase\xbaselib\mylib.lib")

CLASS DatenVerarbeitung
 PROTECTED
   VAR FileExts
   VAR CurrData
   METHOD ValidateFormat
   METHOD Init
   METHOD ReadLines


 EXPORTED
   VAR cFile
   VAR cFReceiver
   VAR cFSender

   METHOD LoadFile
   METHOD NewDocument
   METHOD HandleDragDrop
   METHOD HandleDragLeave
   METHOD HandleDragEnter
ENDCLASS

METHOD DatenVerarbeitung:INIT()
   // Anders als im Drag N Drop Beispiel ist das hier ein Negativliste.
   // Diese Formate können nicht überprüft werden aus meist offensichtlichen Gruenden
   ::FileExts := {".EXE", ".PDF", ".JPG", ".BMP", ".GIF", ".PRG", ".CH", ;
                  ".DLL", ".TEMPLATE"}
RETURN

METHOD DatenVerarbeitung:LoadFile()
   LOCAL oDlg
   SET CHARSET TO ANSI

   oDlg := XbpFileDialog():new()
   oDlg:center := .T.
   oDlg:title  := "Wählen Sie eine EDI Datei aus"
   oDlg:create()

   ::cFile := oDlg:open(,, .F., .F.)

   IF EMPTY(::cFile)
      Return
   ENDIF
RETURN ::cFile

METHOD DatenVerarbeitung:NewDocument( xData)
   LOCAL oDlg
   LOCAL aSizeDLG, aPosDLG, aSizeMLE, oMle

   IF EMPTY(xData)
    RETURN
   ENDIF

   //Dateien werden in neuen, getrennten Fenstern gezeigt
   aSizeDLG    := SetAppWindow():currentSize()
   aSizeDLG[1] *= 0.4
   aSizeDLG[2] *= 0.5

   oDlg := XbpDialog():New( GetApplication():MainForm:DrawingArea, SetAppWindow(),, aSizeDLG,, .F.)

   oDlg:Title := FNAMOEP( xData)
   oDLg:DrawingArea:ClipChildren := .T.
   oDlg:Create()
   oDlg:Close := {|| oDlg:Destroy()}
   oDlg:DrawingArea:Resize := {|aOld, aNew| oMle:Setsize( aNew)}

   aSizeMLE := oDlg:DrawingArea:CurrentSize()

   oMle := XbpMLE():New( oDlg:DrawingArea, oDlg,, aSizeMLE)
   oMle:SetFontCompoundName("10.Courier")
   oMle:editable := .F.
   oMle:Create()
   oMle:cargo := xData
   oMle:SetData( ::ReadLines( xData))

   CenterControl( oDlg)
   oDlg:show()
   SetAppFocus( oDlg)
RETURN

METHOD DatenVerarbeitung:ReadLines( xData)
   LOCAL cEdiInhalt := ""

   cEdiInhalt := MemoRead( xData)
   IF SubStr( cEdiInhalt, AT( "'", cEdiInhalt), 3) != "'" + xCrLf
      cEdiInhalt := StrTran( cEdiInhalt, "'", "'" + xCrLf)
   ENDIF

   ::cFSender   := TOKEN0(TOKEN0(SubStr( cEdiInhalt, AT("UNB+", cEdiInhalt)), "+", 2), ":", 0)
   ::cFReceiver := TOKEN0(TOKEN0(SubStr( cEdiInhalt, AT("UNB+", cEdiInhalt)), "+", 3), ":", 0)

RETURN cEdiInhalt

METHOD Datenverarbeitung:HandleDragEnter( aState, oData)
   UNUSED( aState)
   ::CurrData := ::ValidateFormat( oData)
RETURN

METHOD Datenverarbeitung:ValidateFormat( oData)
   LOCAL aReturn := {}, aReturn_False := {}
   LOCAL aFiles := oData:GetData( XBPCLPBRD_FILELIST )
   LOCAL i, j, nFileExt
   LOCAL cTmp1, cTmp2 := ""
   FOR i := 1 to Len( aFiles)
      cTmp1 := SubStr( aFiles[i], At(".", aFiles[i]))
      nFileExt := AScan( ::FileExts, {|x| Upper(cTmp1) == x} )
      IF nFileExt == 0
         Aadd( aReturn, aFiles[i] )
      ELSE
         Aadd( aReturn_False, FNAMOEP( aFiles[i]) )
      ENDIF
   NEXT

   FOR j := 1 to Len( aReturn_False)
      cTmp2 := cTmp2 + aReturn_False[j] + xCrLf
   NEXT
   IF cTmp2 != ""
      ConfirmBox(,"Folgende Dateien werden nicht unterstütz: " + xCrLf + cTmp2, "Warnung", XBPMB_OK, XBPMB_WARNING)
   ENDIF
RETURN aReturn

METHOD Datenverarbeitung:HandleDragLeave( aState)
   ::CurrData := NIL
RETURN self

METHOD Datenverarbeitung:HandleDragDrop( aState, oData)
   LOCAL i
   FOR i := 1 to Len( ::CurrData)
      ::NewDocument( ::CurrData[i] )
      CheckFile( ::CurrData[i], ::cFReceiver)
   NEXT
RETURN
















