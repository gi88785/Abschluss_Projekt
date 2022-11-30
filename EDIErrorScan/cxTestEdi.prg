// -------------------------------------------------------------------------------
//
// cxTestEdi.PRG
//
// Prüft EDI-Dateien anhand von einer Prüfdatei
//
//
// Last Update : 20.12.2021 (MB)
//
// 09.12.2021 : Erster Entwurf (MTL)
// -------------------------------------------------------------------------------

#include "Common.ch"
#include "FileIO.ch"
#include "DelDbe.ch"
#include "xbtsys.ch"
#include "\xbase\xbaselib\Comp.ch"
#include "EES.ch"

#pragma library ("xbtbase1.lib")
#pragma library ("xbtbase2.lib")
#pragma library ("\xbase\xbaselib\mylib.lib")

/* This is our main procedure
 */
FUNCTION RunEDICheck (cTestFile, cPruefFile, cErgDir)
LOCAL nUNH

SET CHARSET TO ANSI

PUBLIC aErrorList, aWarningList

nParms := PCount()

close all
lProblem   := .F.

cHeute     := HEUTE()
cJetzt     := JETZT()
cSrcLw     := SYS5()

IF PCount() < 2
  RETURN
ENDIF
IF PCount() < 3
  cErgDir  := JUSTPATH(cTestFile)
ELSE
  cErgDir  := cErgDir + "\"
  cErgDir  := STRTRAN(cErgDir, "\\", "\")
ENDIF

oErrorFunc := ErrorBlock( {|e| CCERRORX(e) } ) // Defines Error block and sets the function break to interrupt the program
BEGIN SEQUENCE // *normal program*

cFName    := FNAME(cTestFile)
cFileDate := DTOC(FileDate(cTestFile))
cFileTime := FileTime(cTestFile)

cOutFile  := cErgDir + FNAMOEP(cFName) + ".Fehlerlog"
nOut      := MYFOPEN(cOutFile)                 // Protokollierung

oTF := HBTextReader(cTestFile, "'")
oPF := HBTextReader(cPruefFile, "'")

aErrorList   := {}
aWarningList := {}
aTF          := {}

cArtNr      := ""
cCurrentNAD := ""
cBelDat     := ""
cBelNr      := ""
cICR        := ""
cIdSnd      := ""
cIdRcv      := ""
cIMDQu      := ""
clastSeg    := ""
cMOAQu      := ""
cPFQu       := ""
cPrevArtNo  := ""
cTFQu       := ""
cTyp        := ""

lKopf       := .T.
lFuss       := .F.
lOPT_lOk    := .F.
lPAT        := .F.
lPos        := .F.
lTheNADs    := .F.
lTheRFFs    := .F.
lUNS_Found  := .F.

nKopfEnde   := 1
nKopfAnfang := 0
nNAD1       := 0
nNAD2       := 0
nNextLin    := 0
nPFLin      := 0
nPFL_OPT    := 0
nUNT        := 0

IF oTF:FError() == 0 .AND. oPF:FError() == 0
 FWRITE(nOut, "Prüfung Datei: " + cFName + xCrLf)
 FWRITE(nOut, "Prüfdatum/-zeit: " + cHeute + "/" + cJetzt + xCrLf)

 // Die ganze zu pruefende Datei wird in ein Array gelesen
 DO WHILE !oTF:EOF()
  cZeile := oTF:GetLine()
  cZeile := IIF(LEFT(cZeile, 1) == chr(13), RIGHT(cZeile, len(cZeile)-1), cZeile)
  cZeile := IIF(LEFT(cZeile, 1) == chr(10), RIGHT(cZeile, len(cZeile)-1), cZeile)
  cZeile := IIF(LEFT(cZeile, 1) == chr(13), RIGHT(cZeile, len(cZeile)-1), cZeile)
  cZeile := TRIM(cZeile)
  cSaTP   := SubStr(cZeile, 1, 4)

//Ueberprueft ob die Segmentbezeichner richtig aufgebaut sind, bevor sie ins Array kommen
  IF ("+" $ cSaTP .AND. SubStr(cSaTP, 4, 1) = "+") .OR. cSaTp == "UNA:"
   AADD(aTF, cZeile)
  ELSE
   AADD(aErrorList, "Unbekannter Segmentbezeichner in Zeile: " + cZeile)
  ENDIF
 ENDDO

 nBegLen  := len(aTF)

 DO WHILE !oPF:EOF()
  cZeile   := oPF:GetLine()
  noPFPos  := oPF:nPos
  cZeile   := IIF(LEFT(cZeile, 1) == chr(13), RIGHT(cZeile, len(cZeile)-1), cZeile)
  cZeile   := IIF(LEFT(cZeile, 1) == chr(10), RIGHT(cZeile, len(cZeile)-1), cZeile)
  cZeile   := IIF(LEFT(cZeile, 1) == chr(13), RIGHT(cZeile, len(cZeile)-1), cZeile)
  cInhaltP := Trim(cZeile)     // Prüfzeile

//Auslesen der Praefixe PFL,OPT,CON
  cPrae := substr(cInhaltP,1,3)
//Uebernimmt den Zeileninhalt nach dem Trennzeichen "|"
  cInhaltP := Right( cInhaltP, len(cInhaltP)-RAt( "|", cInhaltP))

//Uebernahme von Satzart und Qualifiern
  cSaP      := SubStr(cInhaltP, 1, 3)

  cPFQu     := EDISPLIT(cInhaltP, 2, 1)
  cPFQu     := IIF(LEFT(cPFQu, 1) = "N" .OR. (LEFT(cPFQu, 1) = "A".AND. cPFQu != "API" .AND. cSaP != "FTX" .AND. ;
               cPFQu != "AAA" .AND. cPFQu != "AAB"), "", cPFQu)

 DO CASE
  CASE cSap == "UNA"
   lOk := ARemove(aTF, 1)
   nUNT := IIF(ASCAN(aTF,{|x| LEFT(x, 4)== "UNT+"}) != 0, ASCAN(aTF, {|x| LEFT(x, 4)== "UNT+"}), LEN(aTF))
   nKopfEnde  := IIF(ASCAN(aTF,{|x| LEFT(x, 4)== "LIN+"},,nUNT) != 0, ASCAN(aTF,{|x| LEFT(x, 4)== "LIN+"},,nUNT), nUNT)

  CASE cSap == "UNB"
   nUNT    := IIF(ASCAN(aTF, {|x| LEFT(x, 4)== "UNT+"}) != 0, ASCAN(aTF, {|x| LEFT(x, 4)== "UNT+"}), LEN(aTF))
   nKopfEnde  := IIF(ASCAN(aTF,{|x| LEFT(x, 4)== "LIN+"},,nUNT) != 0, ASCAN(aTF,{|x| LEFT(x, 4)== "LIN+"},,nUNT), nUNT)

  CASE cSaP == "UNH"
   lKopf    := .T.
   lPos     := .F.
   lTheRFFs := .F.
   lFuss    := .F.
   lPAT     := .F.
   nUNH_PF  := oPF:nPos
   nUNH     := ASCAN(aTF, {|x| LEFT(x, 4)== "UNH+"})
   nUNT     := IIF(ASCAN(aTF, {|x| LEFT(x, 4)== "UNT+"}) != 0, ASCAN(aTF, {|x| LEFT(x, 4)== "UNT+"}), LEN(aTF))
   nSearchEnd := nUNT - nUNH
   nKopfEnde  := IIF(ASCAN(aTF,{|x| LEFT(x, 4)== "LIN+"},,nUNT) != 0, ASCAN(aTF,{|x| LEFT(x, 4)== "LIN+"},,nUNT), nUNT)
   nKopfAnfang:= IIF(ASCAN(aTF,{|x| LEFT(x ,3)== "UNH"},, nUNT) != 0, ASCAN(aTF,{|x| LEFT(x ,3)== "UNH"},, nUNT), "")
   lOk := UNT_CHECK(aTF)
   IF !lOk
    AADD(aErrorList, "Die Segmentanzahl stimmt nicht mit dem Zähler im UNT-Segment ueberein.")
   ENDIF

  CASE cSaP == "BGM"
   cBelNr := EDISPLIT(aTF[ASCAN(aTF, "BGM")], 3, 1)
   FWRITE(nOut, "BelNr: " + cBelNr + xCrLf)

  CASE cSaP == "RFF"
    IF !lTheNADs
       lTheRFFs := .T.
    ENDIF
    nRFF_S   := IIF(ASCAN(aTF,{|x| LEFT(x, 6)== "RFF+" + cPFQu},,nUNT) != 0, ASCAN(aTF,{|x| LEFT(x, 6)== "RFF+" + cPFQu},,nUNT), nSearchStart)

  CASE cSaP == "NAD"
   lKopf    := .F.
   lTheNADs := .T.
   cNAD_Qu  := cPFQu
   lSearch  := "NAD+" + cNAD_Qu
   nNAD1 := IIF(ASCAN(aTF,{|x| LEFT(x, 6)== lSearch},,nUNT) != 0, ASCAN(aTF,{|x| LEFT(x, 6)== lSearch},,nUNT), nSearchStart)
   nNAD2 := IIF(ASCAN(aTF,{|x| LEFT(x, 3)== "NAD"},nNAD1+1, 10) != 0, ASCAN(aTF,{|x| LEFT(x, 3)== "NAD"},nNAD1+1, 10), nUNT)
   nNAD2 := nNAD2 - nNAD1 + 1

  CASE cSaP == "TAX"
   lTheNADs := .F.
   lKopf    := IIF( lPos, .F., .T.)
   lTheRFFs := .F.

  CASE cSaP == "PAT"
   lPAT := .T.
   nPAT := IIF(ASCAN(aTF,{|x| LEFT(x, 3)== "PAT"},,nUNT) != 0, ASCAN(aTF,{|x| LEFT(x, 3)== "PAT"},,nUNT), nSearchStart)

  CASE cSaP == "ALC"
   lPAT := .T.

  CASE cSaP == "LIN"
   lPAT     := .F.
   lTheRFFs := .F.
   lKopf    := .F.
   lPos     := .T.
   nPFLin   := IIF(nPFLin == 0, oPF:nPos, nPFLin)
   nTFLin   := ASCAN(aTF, {|x| LEFT(x, 3)=="LIN"},, nUNT)

   IF len(aTF) >= nTFLin + 1
    nNextLin := ASCAN(aTF, {|x| LEFT(x, 3)=="LIN"}, nTFLin + 1, nUNT)
   ENDIF

   IF nTFLIN != 0
    cEANakt := EDISPLIT(aTF[nTFLIN], 4, 1)
   ENDIF

  CASE cSaP == "IMD"
   cIMDQu := EDISPLIT(cInhaltP, 3, 1)

  CASE cSaP == "UNS"
   lTheRFFs := .F.
   lPAT     := .F.
   lPos     := .F.
   IF ASCAN(aTF, {|x| LEFT(x, 3) == "LIN"},,nUNT) !=0
    oPF:Seek(nPFLin)
   ELSE
    lFuss := .T.
    lPos  := .F.
   ENDIF

  CASE cSaP = "UNT"
   IF ASCAN(aTF, {|x| LEFT(x, 3) == "UNH"}) !=0
    oPF:Seek(nUNH_PF)
    lOk := ERRORPRINT()
   ELSE
    lOk := ERRORPRINT()
   ENDIF

 END CASE

// Je nach Status des Segments, unterschiedliche Behandlung bei nicht Vorhandensein
  IF cIMDQu == ""
   cDummy := cSaP + "+" + cPFQu
  ELSE
   cDummy := cSaP + "+" + cPFQu + "+" + cIMDQu
  ENDIF

  nSearchStart := IIF(lKopf, nKopfAnfang, nSearchStart)
  nSearchStart := IIF(lTheRFFs, nRFF_S, nSearchStart)
  nSearchStart := IIF(lTheNADs, nNAD1, nSearchStart)
  nSearchStart := IIF(lPAT, nPat, nSearchStart)
  nSearchStart := IIF(lPos, nTFLin, nSearchStart)

  nSearchEnd   := nUNT
  nSearchEnd   := IIF(lKopf, nKopfEnde - nSearchStart, nSearchEnd)
  nSearchEnd   := IIF(lPAT,2,nSearchEnd)

  nSearchEnd   := IIF(lPos .AND. nNextLin >= nTFLin, IIF(nNextLin = nTFLin, 2, nNextLin - nTFLin), nSearchEnd)
  nSearchEnd   := IIF(lTheRFFs, 2, nSearchEnd)
  nSearchEnd   := IIF(lTheNADs, nNAD2, nSearchEnd)
  nSearchEnd   := IIF(lFuss, nUNT, nSearchEnd)
  nSearchEnd   := IIF(cSaP == "UNZ", len(aTF), nSearchEnd)
  nSearchEnd   := IIF(nSearchEnd < 0, 1, nSearchEnd)

  nFound := ASCAN(aTF, cDummy, nSearchStart, nSearchEnd)

  IF cPrae == "PFL"
  lOPT_lOk := .F.
   IF nFound = 0
      IF cSap == "UNS" .AND. lUNS_Found
      Else
         lOk := SONDERLOCKE(cDummy)
         IF !lOk
            IF cDummy == "DTM+"
               AADD(aErrorList, "Das Datum zu Segment " + clastSeg + " fehlt.")
            ELSE
               AADD(aErrorList, "Segment: " + cDummy + " fehlt." + xCrLf)
            ENDIF
            lOk := EXTRAINFO(-1)
         ENDIF
      ENDIF
   ELSE
    lOk := VERGLEICH(aTF[nFound], cInhaltP)
    AREMOVE(aTF,nFound)
    nSearchEnd --
    nNAD1 := IIF(nNAD1 > 1, nNAD1--  , nNAD1)
    nNAD2 --
    nKopfEnde --
    nUNT --
    nNextLin := IIF(nNextLin > 0, nNextLin --, 0)
    lUNS_Found := IIF(cSaP == "UNS" .AND. lOk .AND. !lUNS_Found, .T., lUNS_Found)
   ENDIF

  ELSEIF cPrae == "OPT"
  lOPT_lOk := .F.
   IF nFound != 0
    lOk := VERGLEICH(aTF[nFound], cInhaltP)
    lOPT_lOk := IIF(lOk, .T., .F.)
    AREMOVE(aTF,nFound)
    nSearchEnd --
    nNAD1 := IIF(nNAD1 > 1, nNAD1--  , nNAD1)
    nNAD2 --
    nKopfEnde --
    nUNT --
    nNextLin := IIF(nNextLin > 0, nNextLin --, 0)
   ENDIF

  ELSEIF cPrae == "CON" .AND. lOPT_lOk
   IF nFound != 0 .AND. (nSearchEnd >= nSearchStart)
    lOk := VERGLEICH(aTF[nFound], cInhaltP)
    AREMOVE(aTF,nFound)
    nSearchEnd --
    nKopfEnde --
    nUNT --
    nNextLin := IIF(nNextLin > 0, nNextLin --, 0)
   ENDIF
  ENDIF
  cIMDQu   := ""
  clastSeg := cDummy
 ENDDO
ENDIF

FOR i := 1 to len(aTF)
 IF "+" $ LEFT(aTF[i],3)
  AADD(aErrorList, "Fehlerhafter Segmentbezeichner in Zeile: " + aTF[i] + xCrLf)
 ENDIF
 IF RIGHT(aTF[i],1) == "?"
  AADD(aErrorList, "Reserviertes Sonderzeichen (?) am Zeilenende in Zeile: " + aTF[i] + xCrLf)
 ENDIF
NEXT

oTF:Destroy()

FCLOSE(nOut)

RECOVER  // This happens if an error occurs.
   FWRITE(nOut, "PROGRAMMFEHLER bei der PRÜFUNG !"+ xCrLf)
   FCLOSE(nOut)
   close all
   ErrorBlock(oErrorFunc)
ENDSEQUENCE

ErrorBlock(oErrorFunc)
RETURN (cOutFile)

//-------------------------------------------------------------------------------------------------
FUNCTION EDISPLIT(cInhalt, nPos1, nPos2)
  cRet := TOKEN0(TOKEN0(cInhalt + "++++++" , "+", nPos1 - 1) + "::::::", ":", nPos2 - 1)
RETURN (cRet)

//-------------------------------------------------------------------------------------------------
FUNCTION TOKENIZE(cText)
  LOCAL aReturn := {}, cSep1 := ":", cSep2 := "+", cEsc  := "?", nEsc := 0, nSep1 := 0, ;
   nSep2 := 0, anf := 1, ende := 0, cTmp := cText
  FOR i := 1 TO len(cTmp)
    nEsc  := IIF(SubStr(cTmp, i, 1) == cEsc, i, nEsc)
    nSep1 := IIF(SubStr(cTmp, i, 1) == cSep1, i, nSep1)
    nSep2 := IIF(SubStr(cTmp, i, 1) == cSep2, i, nSep2)
    IF (nSep1 == i .AND. nEsc != i - 1) .OR. (nSep2 == i .AND. nEsc != i - 1)
      ende := i
      AADD(aReturn, SubStr(cTmp, anf, ende - anf))
      anf = ende + 1
    ENDIF
  NEXT
  IF anf <= len(cTmp)
    AADD(aReturn, SubStr(cTmp, anf, len(cTmp) - anf + 1))
  ENDIF
RETURN(aReturn)

//-------------------------------------------------------------------------------------------------
FUNCTION TESTDAT(cDat, cTest)
  LOCAL lRet
  IF VAL(cDat) > 0 .AND. len(cDat) == len(cTest)
    lRet := .T.
  ELSE
    lRet := .F.
    AADD(aErrorList, "Fehler im Datum: " + cDat)
  ENDIF
RETURN lRet

//-------------------------------------------------------------------------------------------------
FUNCTION VERGLEICH(cDat1, cDat2)
  LOCAL lRet := .T., nFehler := 0
  IF LEFT(cDat1, 3) == "NAD"
   aEl1 := NAD_SPLIT(cDat1)
   aEl2 := NAD_SPLIT(cDat2)
  ELSE
   aEl1 := TOKENIZE(cDat1)
   aEl2 := TOKENIZE(cDat2)
  ENDIF

  FOR i := 1 TO len(aEl1)
  lPFL_OPT := .F.
    IF i <= len(aEl2)
      cEl2_i := aEl2[i]
//Abfrage ob in Segmenten, optionale Angaben moeglich sind. Sollten sie nicht vorhanden sein, darf es nicht auf Fehler laufen.
      IF LEFT(aEl2[i], 1 ) == "@"
       cEl2_i   := SubStr(cEl2_i, 2)
       lPFL_OPT := .T.
       nPFL_OPT ++
      ENDIF

      DO CASE
      CASE cEl2_i == "HHMM"
        lRet := TESTDAT(aEl1[i], "HHMM")
      CASE cEl2_i == "JJMMTT"
        lRet := TESTDAT(aEl1[i], "JJMMTT")
      CASE cEl2_i == "JJJJMMTT"
        lRet := TESTDAT(aEl1[i], "JJJJMMTT")

      CASE LEFT(cEl2_i, 1) == "N" .AND. VAL(RIGHT(cEl2_i, 2)) > 0   // Numerisch
         lOk := ISVAL(aEl1[i])
         IF lOk
          IF len(aEl1[i]) > VAL(RIGHT(cEl2_i, 2))
            AADD(aErrorList, "Numerischer Wert zu lang im Feld: " + aEl1[i] + " In Segment: " + cDat1)
            lRet := .F.
            nFehler --
          ELSEIF VAL(RIGHT(cEl2_i, 2)) > 0 .AND. !lPFL_OPT .AND. (Empty(aEl1[i]) .OR. aEl1[i] == NIL)
            AADD(aErrorList, "Fehlender Eintrag im Segment:" + cDat1)
            lRet := .F.
            nFehler --
          ENDIF
         ELSEIF !lOk .AND. aEl1[i] == "" .AND. lPFL_OPT
         ELSE
          AADD(aErrorList, "In Feld " + aEl1[i] + " in Segment " + cDat1 + " wurde ein nicht numerischer Wert gefunden.")
          lRet := .F.
          nFehler --
         ENDIF

      CASE LEFT(cEl2_i, 1) == "A" .AND. VAL(SUBSTR(cEl2_i, 2)) > 0   // Text
        IF len(aEl1[i]) > VAL(SUBSTR(cEl2_i, 2))
          AADD(aErrorList, "Eintrag zu lang in Feld: " + aEl1[i] + ", In Segment: " + cDat1)
          lRet := .F.
          nFehler --
        ENDIF
        IF VAL(SUBSTR(cEl2_i, 2)) > 0 .AND. !lPFL_OPT .AND. (Empty(aEl1[i]) .OR. aEl1[i] == NIL)
         IF aEl1[1] == "NAD"
            cDummy := aEl2[1] + "+" + aEl2[2]
            DO CASE
             CASE i == 10
              AADD(aErrorList, "Fehlender Name im Segment " + cDummy)
             CASE i == 15
              AADD(aErrorList, "Fehlende Strasse und Hausnummer bzw. Postfach im Segment " + cDummy)
             CASE i == 19
              AADD(aErrorList, "Fehlender Ort im Segment " + cDummy)
             CASE i == 21
              AADD(aErrorList, "Fehlende PLZ im Segment " + cDummy)
             CASE i == 22
              AADD(aErrorList, "Fehlender Ländercode im Segment " + cDummy)
             OTHER
              AADD(aErrorList, "Fehlender Eintrag im Segment:" + cDat1)
            ENDCASE
            cDummy := ""
            nFehler --
            lRet := .F.
         ELSE
          AADD(aErrorList, "Fehlender Eintrag im Segment:" + cDat1)
          nFehler --
          lRet := .F.
         ENDIF
        ENDIF
      CASE aEl1[i] != cEl2_i
        AADD(aErrorList, "Fehler im Eintrag: " + aEl1[i] + " In Segment: " + cDat1 + xCrLf + ;
                         "Erwartet wird: " + cEl2_i + ". Gesendet wurde: " + aEl1[i])
        nFehler --
        lRet := .F.
      ENDCASE
    ENDIF
  NEXT

// Der optionale Anteil am Pflichtsegment darf nicht als Fehler gewertet werden
  IF len(aEl1) < (len(aEl2) - nPFL_OPT)
   lJustOpt := .T.
   FOR i := len(aEl1) to len(aEl2)
    IF LEFT(aEl2[i],1) != "@"
     lJustOpt := .F.
     EXIT
    ENDIF
   NEXT
   IF !lJustOpt
    AADD(aErrorList, "Das gelieferte Segment ist nicht vollständig: " + cDat1)
   ENDIF
   nFehler --
   lRet := .F.
  ENDIF

  IF !lRet
   lOk := Extrainfo(nFehler)
  ENDIF
  nPFL_OPT := 0
RETURN lRet

//-------------------------------------------------------------------------------------------------
FUNCTION ERRORPRINT()
 LOCAL lRet := .T.

 IF len(aErrorList) == 0 .AND. len(aWarningList) == 0
  FWRITE(nOut, "Es konnten keine Fehler im Beleg gefunden werden." + xCrLf)
 ELSE
  FOR i:= 1 TO len(aWarningList)
   FWRITE(nOut, "WARNUNG: " + aWarningList[i] + xCrLf)
   IF i == len(aWarningList)
    FWRITE(nOut, xCrLf)
   ENDIF
  NEXT
  FOR i:= 1 TO len(aErrorList)
  IF SUBSTR(aErrorList[i], 1, 8) = "Folgende"
   FWRITE(nOut, xCrLf + aErrorList[i] + xCrLf)
  ELSE
   FWRITE(nOut, "ERROR: " + aErrorList[i] + xCrLf)
   IF i == len(aErrorList)
      FWRITE(nOut, xCrLf)
   ENDIF
  ENDIF
  NEXT
  aErrorList   := {}
  aWarningList := {}
 ENDIF
RETURN lRet

//-------------------------------------------------------------------------------------------------
FUNCTION SONDERLOCKE(cPF_Line)
// Hier werden Segmente abgefangen, die ähnlich sind, aber doch nicht ganz das selbe.
// Sie sollen geprueft werden, aber nicht sofort als Fehler ausgegeben werden.
LOCAL lSL := .F.
 DO CASE
  CASE cPF_Line == "IMD+F"
   cAlternative := "IMD+A++:::A256"
   nFound_SL := ASCAN(aTF, {|x| LEFT(x, 5) == "IMD+A"},,nUNT)
   IF nFound_SL != 0
      lSL := VERGLEICH(aTF[nFound_SL], cAlternative)
      IF lSL
         AREMOVE(aTF,nFound_SL)
      ENDIF
   ENDIF
 ENDCASE
RETURN lSL

//-------------------------------------------------------------------------------------------------
FUNCTION ISVAL(cTxt)
LOCAL i , lRet := .F.
IF ISDIGIT(cTxt)
  lRet = .T.
ENDIF
FOR i = 1 TO LEN(cTxt)
  IF (!ISDIGIT(SubStr(cTxt, i, 1))  .AND. (SubStr(cTxt, i, 1) != "."  .OR. SubStr(cTxt, i, 1) != ","))
   IF SubStr(cTxt, i, 1) $ {",", ".", "-", "/"}
    lRet := .T.
   ELSE
    lRet := .F.
    EXIT
   ENDIF
  ENDIF
NEXT
RETURN (lRet)

//-------------------------------------------------------------------------------------------------
FUNCTION NAD_SPLIT(cNAD)

LOCAL aNAD_SPlit := {}
 // G02
 AADD(aNAD_SPlit, EDISPLIT(cNAD, 1, 1))
 // 3035
 AADD(aNAD_SPlit, EDISPLIT(cNAD, 2, 1))
 // C082
 AADD(aNAD_SPlit, EDISPLIT(cNAD, 3, 1))
 AADD(aNAD_SPlit, EDISPLIT(cNAD, 3, 3))
 // C058 Name und Anschrift
 FOR i := 1 to 5
  AADD(aNAD_SPlit, EDISPLIT(cNAD, 4, i))
 NEXT
 // C080 Name des Beteiligten
 FOR i := 1 to 5
  AADD(aNAD_SPlit, EDISPLIT(cNAD, 5, i))
 NEXT
 // C059 Straße
 FOR i := 1 to 4
  AADD(aNAD_SPlit, EDISPLIT(cNAD, 6, i))
 NEXT
 // C3164 Ort
 AADD(aNAD_SPlit, EDISPLIT(cNAD, 7, 1))
 // C3229 Region/Bundesland
 AADD(aNAD_SPlit, EDISPLIT(cNAD, 8, 1))
 // C3251 PLZ
 AADD(aNAD_SPlit, EDISPLIT(cNAD, 9, 1))
 // C3207 Land, codiert
 AADD(aNAD_SPlit, EDISPLIT(cNAD, 10, 1))
RETURN (aNAD_SPlit)

//-------------------------------------------------------------------------------------------------
FUNCTION UNT_CHECK(aCopy)
LOCAL lCheck := .F., nUNH := nUNT_Check := 0

 nUNH       := IIF(ASCAN(aCopy, {|x| LEFT(x, 4) == "UNH+"}) != 0, ASCAN(aCopy, {|x| LEFT(x, 4) == "UNH+"}), nUNH)
 nUNT_Check := IIF(ASCAN(aCopy, {|x| LEFT(x, 4) == "UNT+"}) != 0, ASCAN(aCopy, {|x| LEFT(x, 4) == "UNT+"}), nUNT_Check)
 IF nUNH != 0 .AND. nUNT_Check != 0
  IF VAL(EDISPLIT(aCopy[nUNT_Check], 2, 1)) == nUNT_Check - nUNH + 1
   lCheck := .T.
/*  ELSE
   FOR i := nUNH TO nUNT_Check
    FWRITE(nOut, aCopy[i] + xCrLf)
   NEXT
*/   
  ENDIF
 ENDIF
aCopy := {}
RETURN lCheck

//-------------------------------------------------------------------------------------------------
PROCEDURE EXTRAINFO(nShift)
LOCAL cDummy := ""

DO CASE
CASE lKopf
 cDummy :="Folgende Fehler traten im Belegkopf auf:"
 IF ASCAN(aErrorList, cDummy) == 0
  AADD(aErrorList, cDummy, len(aErrorList))
 ENDIF

CASE lTheNADs
 cDummy :="Folgende Fehler traten im NAD+" + cNAD_Qu + " Abschnitt auf:"
 IF ASCAN(aErrorList, cDummy) == 0
  AADD(aErrorList, cDummy, len(aErrorList) + nShift +1)
 ENDIF

CASE lPos
 cDummy := "Folgende Fehler traten im Positionsteil, bei Artikel " + cEANakt + " auf:"
 IF ASCAN(aErrorList, cDummy) == 0
  AADD(aErrorList, cDummy, len(aErrorList))
 ENDIF

CASE lFuss
 cDummy :="Folgende Fehler traten im Belegfuss auf:"
 IF ASCAN(aErrorList, cDummy) == 0
  AADD(aErrorList, cDummy, len(aErrorList))
 ENDIF
ENDCASE
RETURN
