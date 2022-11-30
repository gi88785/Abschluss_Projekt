//////////////////////////////////////////////////////////////////////
//
//  EDI Error Scan.PRG
//
//  Copyright:
//      stratEDI GmbH, (c) 2022. Alle Rechte vorbehalten.
//
//  Inhalt:
//      Main Routine, AppSys() sowie die Kernfunktionen für die EDI ErrorScan
//
//////////////////////////////////////////////////////////////////////

#include "Gra.ch"
#include "Xbp.ch"
#include "AppEvent.ch"
#include "EES.ch"
#include "DelDbe.ch"

PROCEDURE MAIN()
   LOCAL nEvent, mp1, mp2, oXbp
   SET CHARSET TO ANSI

   /*
    Hier wird die Datenbank aufgerufen, sofern sie nicht vorhanden ist
   */
    lOk := Make_COD()

   DO WHILE .T.
    nEvent := AppEvent( @mp1, @mp2, @oXbp)
    oXbp:handleEvent( nEvent, mp1, mp2)
   ENDDO
RETURN

// Routine die das Programm beendet

PROCEDURE AppQuit()
   LOCAL nButton

   nButton := ConfirmBox( , ;
                        "Wollen Sie das Programm beenden?", ;
                        "Programm schließen", ;
                        XBPMB_YESNO, ;
                        XBPMB_QUESTION+XBPMB_APPMODAL+XBPMB_MOVEABLE )

   IF nButton == XBPMB_RET_YES
    CLOSE ALL
    QUIT
   ENDIF
   CLOSE DATABASE
RETURN

PROCEDURE AppSys
   LOCAL oXbpm, aPos[2], aSize
   LOCAL oXbp1, oXbp2, oDV, oMain

   //Fenstergrosse wird auf 80% der Auflosung festgelegt
   aSize    := SetAppWindow():currentSize()
   aPos[1]  := 0.1 * aSize[1]
   aPos[2]  := 0.1 * aSize[2]
   aSize[1] *= 0.8
   aSize[2] *= 0.8

   oDV := Datenverarbeitung():new()

   //Anwendungsfenster erzeugen
   oMain       := XbpDialog():new(,, aPos, aSize,, .F.)
   oMain:title := "EDI Error Scan"
   oMain:close := {||AppQuit()}
   oMain:tasklist :=.T.
   oMain:drawingArea:ClipChildren := .T.
   oMain:drawingArea:DropZone  := .T.
   oMain:drawingArea:DragDrop  := {|aState, oData| oDV:HandleDragDrop( aState, oData)}
   oMain:drawingArea:DragEnter := {|aState, oData| oDV:HandleDragEnter( aState, oData)}
   oMain:drawingArea:DragLeave := {|aState, oData| oDV:HandleDragLeave( aState, oData)}
   oMain:create()
   oMain:drawingArea:SetColorBG( XBPSYSCLR_APPWORKSPACE)
   SetAppWindow( oMain)

   drawingArea := oMain:drawingArea

   MenuCreate( oMain:menuBar())

   oMain:show()
   SetAppFocus( oMain)
RETURN

PROCEDURE Make_COD()
   LOCAL cSrcLw    := lower(SYS5())
   LOCAL a1, cCodeFile
   LOCAL aStructure := { { "GLN"   , "C",   13, 0 }, ;
                         { "Name"  , "C",   30, 0 }, ;
                         { "Nachrichtenart"  , "C",   30, 0 }, ;
                         { "Dateiname"  , "C",  250, 0 }  }
   FIELD GLN, Name
   PUBLIC cDbPath   := upper(cSrcLw)  + "\" + CurDir()
   PUBLIC nDB
   PUBLIC cAlias
   PUBLIC cCodeDBf

   cCodeFile     := cDbPath + "\config.cod"
   cCodeFile_alt := cDbPath + "\config.alt"
   cCodeDBf      := cDbPath + "\Prufcode.DBF"


   DO CASE
    CASE !File(cCodeFile) .AND. !File(cCodeDBf) .AND. File(cCodeFile_alt)
      MsgBox("Es ist eine alte Version der Zuordnungstabelle vorhanden." + xCrLf + ;
             "Möglicherweise sind nicht alle Angaben aktuell.", "Warnung" )
    CASE !File(cCodeFile) .AND. !File(cCodeDBf) .AND. !File(cCodeFile_alt)
      MsgBox("Es ist nicht möglich eine Zuordnungtabelle zu öffen oder zu erstellen." + xCrLf + ;
             "Stellen Sie sicher, dass eine gültige config.cod im Programmverzeichnis liegt.", "Fatal Error" )
    CASE File(cCodeFile)
      MsgBox("Es wurde eine neue Zuordnungstabelle erstellt." )
   ENDCASE

   IF File( cCodeDBf) .AND. File(cCodeFile)
    DELETE File( cCodeDBf)
   ENDIF
   IF File(cCodeFile_alt) .AND. File(cCodeFile)
    DELETE File(cCodeFile_alt)
   ENDIF

   IF !File( cCodeDBf) .AND. (File(cCodeFile) .OR. File(cCodeFile_alt))
    DbCreate(cCodeDBf, aStructure, "DBFDBE")
    USE (cCodeDBf) EXCLUSIVE
    IF !neterr()
     nDB := select()
     cAlias := alias()
    ENDIF
    IF File(cCodeFile)
     append from (cCodeFile) VIA "DELDBE"
    ELSEIF File(cCodeFile_alt)
     append from (cCodeFile_alt) VIA "DELDBE"
    ENDIF
    append blank
    replace (cAlias) -> GLN with "EOF"
    RENAME (cCodeFile) TO (cCodeFile_alt)
    CLOSE DATABASE
   ENDIF
RETURN

PROCEDURE CheckFile(cFilePath, cEmpfaenger)
   LOCAL oLogEdit := Datenverarbeitung():new()
   LOCAL cInhaltCodeFile := cPruefdatei := cEmpfGLN := cPruefdatei := cPruefdatei_Pfad := ""
   FIELD GLN, Dateiname

   IF cFilePath == "" .OR. cFilePath == NIL
      MSGBOX("Öffnen Sie zuerst eine Datei.", "Achtung!")
      RETURN
   ENDIF

   SELECT 1
   USE (cCodeDBf)
   IF !NetErr()
    GOTO TOP
    cAlias := Dbf()
   ENDIF

   DO WHILE .not. EOF()
      IF alltrim( GLN) == cEmpfaenger
         cPruefdatei := ALLTRIM( Dateiname)
         EXIT
      ENDIF
      SKIP
   ENDDO

   IF cPruefdatei == ""
      MsgBox("Zu der GLN "+ cEmpfaenger + " existiert keine Prüfvorlage.", "Warnung!")
      cOk := Unknown_Receiver( cEmpfaenger, FNAMOEP( cFilePath))
      IF cOk != "Abbruch"
       SELECT 1
       USE (cCodeDBf)
       DbGoTop()

       DO WHILE .NOT. EOF()
        IF alltrim( Name) == cOk
          cPruefdatei := alltrim( Dateiname)
        ENDIF
        SKIP
       ENDDO
       cPruefdatei_Pfad := cDbPath + "\Vorlagen\" + cPruefdatei
       msgbox("Gesucht: "+ cOk + ", Gefunden: " + cPruefdatei, Var2Char( RecNo()) + "Tadaa")
       IF !File(cPruefdatei_Pfad)
        lOk := ErrMessage(1)
       ELSE
        oLogEdit:NewDocument(RunEDICheck( cFilePath, cPruefdatei_Pfad))
       ENDIF
      ENDIF
   ELSE
      cPruefdatei_Pfad := cDbPath + "\Vorlagen\" + cPruefdatei
      IF !File(cPruefdatei_Pfad)
       lOk := ErrMessage(1)
      ELSE
       oLogEdit:NewDocument(RunEDICheck( cFilePath, cPruefdatei_Pfad))
      ENDIF
   ENDIF
RETURN

PROCEDURE ErrMessage( nErrNumber)
 DO CASE
  CASE nErrNumber == 1
   MsgBox("Die benötigte Datei liegt nicht im Verzeichnis: " + xCrLf + xCrLf + cDbPath + "\Vorlagen\" + xCrLf + xCrLf + ;
          "Bitte stellen Sie sicher, dass die notwendigen Vorlagen im entsprechenden Verzeichnis liegen.","Achtung!")
 ENDCASE
RETURN

FUNCTION Unknown_Receiver( cUnk_GLN, cDatName)
   LOCAL nEvent, mp1, mp2, aSize
   LOCAL oDlg, oXbp, oCombo, oConfirm, drawingArea, aEditControls := {}
   LOCAL cAuswahl := "Bitte wählen", cTest := "", cEmpfName := cEmpfGLN := ""
   FIELD GLN, Name
   SET CHARSET TO ANSI
   aSize := {600,300}

   oDlg := XbpDialog():new( GetApplication():MainForm:DrawingArea,  , {300, 300}, aSize, , .F.)
   oDlg:taskList     := .T.
   oDlg:clipChildren := .T.
   oDlg:title := "Vorlage für unbekannten Empfänger in Datei: " + cDatName
   oDlg:Close := {|| oDlg:Destroy()}
   oDlg:create()

   drawingArea := oDlg:drawingArea
   drawingArea:setFontCompoundName( "8.Arial" )

   oCombo := XbpCombobox():new( drawingArea, , {80,100}, {424,100}, { { XBP_PP_BGCLR, XBPSYSCLR_ENTRYFIELD } }, .T. )
   oCombo:markMode := XBPLISTBOX_MM_SINGLE
   oCombo:type := XBPCOMBO_DROPDOWNLIST
   oCombo:create()

   oCombo:XbpSLE:dataLink := {|x| IIf(x == NIL, cAuswahl, cAuswahl := x)}
   oCombo:XbpSLE:setData()

   bAction := {|mp1, mp2, obj|cTest := obj:XbpSLE:getData()}
   oCombo:ItemSelected := bAction

   oConfirm := XbpPushButton():new(drawingArea, , {150, 100}, {100, 20}, ,.T.)
   oConfirm:caption := "Vorlage nutzen"
   oConfirm:LbClick :={|| IIF(cTest == "", msgbox("Bitte Empfänger auswählen","Achtung!"),PostAppEvent(xbeP_Close,,, oDlg))}
   oConfirm:create()

   oCancel := XbpPushButton():new(drawingArea, , {350, 100}, {100, 20}, ,.T.)
   oCancel:caption := "Abbrechen"
   oCancel:LbClick := {|| cTest := "Abbruch",  PostAppEvent(xbeP_Close,,, oDlg)}
   oCancel:create()

   USE (cCodeDBf) NEW
   IF !NetErr()
    GOTO TOP
   ENDIF

   DO WHILE .not. EOF()
      IF substr( alltrim( GLN), 1, 2) == "!#"
      ELSE
       oCombo:addItem( alltrim( Name))
      ENDIF
      SKIP
   ENDDO

   oXbp := XbpStatic():new( drawingArea, , {150,200}, {250,16}, { { XBP_PP_BGCLR, -255 } } )
   oXbp:caption := "Prüfvorlage für GLN " + cUnk_GLN + " wählen"
   oXbp:clipSiblings := .T.
   oXbp:options := XBPSTATIC_TEXT_CENTER
   oXbp:create()

   oDlg:show()
   SetAppFocus(oDlg)

   DO WHILE nEvent <> xbeP_Close
    nEvent := AppEvent( @mp1, @mp2, @oXbp)
    IF nEvent == xbeP_Close .AND. cTest == ""
     nEvent := xbe_None
    ELSE
     oXbp:handleEvent( nEvent, mp1, mp2)
    ENDIF
   ENDDO
RETURN cTest




