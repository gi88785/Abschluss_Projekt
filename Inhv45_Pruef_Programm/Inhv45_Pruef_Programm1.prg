//////////////////////////////////////////////////////////////////////
///
/// InhV45_Pruef_Programme
///
/// Prüft die Syntaktische Korrekheit eingehenden Test-dateien
/// - stratEDI standard Inhouse Schnitsstelle v45
///
/// 28.11.2022 : Erster Entwurf (GB)
///
//////////////////////////////////////////////////////////////////////
///

/* create object for XBP and specify coordinates
oButton := XbpPushButton():new( , , {10,20}, {80,30} )

// define variables for configuring system resources: in this
// case the text which is displayed on the pushbutton
oButton:caption := " Delete "

// request system resource
oButton:create()
*/


PROCEDURE Main()
          LOCAL cFirstName, cLastName
          DbUseArea( .T., "FOXCDX", "Customer.dbf", "Cust", .T. )

          IF .NOT. Used()
              QUIT
          ENDIF

          cFirstName := Cust->FIRSTNAME
          cLastName  := Cust->LASTNAME

          ? Trim( cFirstName ), Trim( cLastName )
RETURN


CLASS Test
      Exported:
      Method Init, show
ENDCLASS

METHOD Test:init
RETURN SELF

METHOD Test:show
RETURN SELF

