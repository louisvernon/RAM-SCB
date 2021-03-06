!==============================================================================
module ModRamCouple
!    This module contains variables and routines for coupling RAM-SCB to
!    the SWMF: BATS-R-US and Ridley_Serial/RIM.
!    Copyright (c) 2016, Los Alamos National Security, LLC
!    All rights reserved.
!==============================================================================

  use ModRamMain, ONLY: nT, nR, nE, nPa, Real8_, nRextend

  implicit none
  save

  public :: set_type_mhd
  public :: generate_flux
  public :: sort_mhd_lines

  ! Can be single, multiS, or multiF to indicate MHD run.
  character(len=6), public :: TypeMhd='single'

  ! Indices of total and species density and temperature.
  ! These are NEVER assumed to increase robustness.
  integer, public :: &
       TotalRho_ = -1, TotalPres_= -1, &
       RhoH_ = -1, PresH_ = -1, &
       RhoHe_= -1, PresHe_= -1, &
       RhoO_ = -1, PresO_ = -1, &
       RhoSw_= -1, PresSw_= -1, &
       Ppar_ = -1, Bmin_  = -1

  logical :: DoMultiFluidGMCoupling = .false.

  ! Coupling P to SWMF:
  ! The iono footprints from BATS should be stored here:
  real(kind=Real8_), public :: IonoMap_DSII(3,2,nRextend,nT) = 0.0

  ! Container for MHD density and pressure at outer boundary.
  ! Indices are (dens:pres,Local Time,species[all, h, he, O])
  real(kind=Real8_), public :: MhdDensPres_VII(3,nT,4)
  real(kind=Real8_), public :: FluxBats_IIS(nE, nT, 1:4) = 0
  real(kind=Real8_), public :: PMhdGhost(nT)=0! MHD pressure at RAM ghost cells.
 real(kind=Real8_), public :: FluxBats_anis(nE,nPa,nT,1:4) = 0.

  ! Variables for B-field coupling with MHD:
  integer, public, parameter   :: nPointsMax = 200
  integer, public :: nRadSWMF, nRadSwmfVar, nRadSwmfVarInner, &
       nLonSWMF, nLinesSWMF, nPoints
  real(kind=Real8_), public :: iEnd(2*(nR+1)*nT)
  real(kind=Real8_), public, allocatable :: MhdLines_IIV(:,:,:)
  real(kind=Real8_), public, allocatable :: xSWMF(:,:,:), ySWMF(:,:,:), &
       zSWMF(:,:,:), LatSWMF(:,:), LonSWMF(:,:)
  real(kind=Real8_), public, dimension(nR+1,nT-1) :: &
       xEqSWMF, yEqSWMF, pEqSWMF, nEqSWMF
  

  ! Variables for coupling to SWMF-IE component:
  integer, public :: nIePhi=0, nIeTheta=0
  real(kind=Real8_), public, allocatable :: SwmfIonoPot_II(:,:)
  real(kind=Real8_), public              :: SwmfPot_II(nR+1, nT) = 0.0
contains

  !===========================================================================
  subroutine set_type_mhd(NameVarIn, nVarIn)
    ! Parse NameVar to determine if the info from the MHD code 
    ! is single/ multispecies or multifluid.  Check for H, He, 
    ! and O+ in simulation if multi.  If those cannot be found, 
    ! revert to single species.
    
    implicit none

    character(len=200), intent(in) :: NameVarIn
    integer, intent(in)            :: nVarIn

    character(len=200) :: NameVar
    integer :: i, nChar

    logical :: DoTest, DoTestMe
    character(len=*), parameter :: NameSub = 'set_type_mhd'
    !------------------------------------------------------------------------
    call CON_set_do_test(NameSub, DoTest, DoTestMe)

    NameVar = trim(NameVarIn)

    ! Parse NameVar to locate variables of interest.
    do i=1, nVarIn
       nChar=index(NameVar, ' ')
       if (nChar .eq. -1) nChar = len(trim(NameVar))
       select case ( trim(NameVar(1:nChar)) )
       case ('rho')
          TotalRho_ = i
       case ('Rho')
          TotalRho_ = i
       case ('p')
          TotalPres_ = i
       case ('P')
          TotalPres_ = i
       case ('RhoH')
          RhoH_ = i
       case ('HpRho')
          RhoH_ = i
       case ('RhoHe')
          RhoHe_ = i
       case ('RhoO')
          RhoO_ = i
       case ('OpRho')
          RhoO_ = i
       case ('SwRho')
          RhoSw_ = i
       case ('HpP')
          PresH_ = i
       case ('HeP')
          PresHe_ = i
       case ('OpP')
          PresO_ = i
       case ('SwP')
          PresSw_ = i
      case('Ppar')
          Ppar_ = i
       case ('ppar')
          Ppar_ = i
       end select
       NameVar = trim( NameVar(nChar + 1:len(NameVar)) )
    end do

    if ( all((/ RhoH_,  RhoHe_, RhoO_ /)  .ne. -1) ) TypeMhd = 'multiS'
    if ( all((/ PresH_, PresHe_,PresO_ /) .ne. -1) ) TypeMhd = 'multiF'
    if ( all((/ PresSw_,PresH_ ,PresO_ /) .ne. -1) ) TypeMhd = 'mult3F'
    if ( Ppar_ .ne. -1) TypeMhd = 'anisoP'

    if(DoTestMe) then
       write(*,*) 'RAM_SCB: TypeMhd = ', TypeMhd
       write(*,*) 'RAM_SCB: MHD Indices = ', &
            'total = ', TotalRho_, TotalPres_, &
            'h = ', RhoH_, PresH_, &
            'he = ', RhoHe_,PresHe_, &
            'o = ', RhoO_, PresO_, &
            'sw = ', RhoSw_,PresSw_
    end if

  end subroutine set_type_mhd

  !===========================================================================
  subroutine sort_mhd_lines(nVarIn, nPointIn, BufferLine_VI)
    ! Sort MHD field lines & associated state variables into manageable array.
    ! Extend field lines in preparation for calculation of Euler potential
    ! surfaces.  Create equatorial variables.
    
    use ModRamMain,     ONLY: Real8_, nR, nT, lz, phi, NameBoundMag, &
         IsComponent, nRextend
    use ModRamFunctions,ONLY: get_dipole_trace

    implicit none

    integer,           intent(in) :: nVarIn, nPointIn
    real(kind=Real8_), intent(in) :: BufferLine_VI(nVarIn, nPointIn)

    integer           :: i, j, iRad, iLon, iLine, iPointBuff, iPointLine
    real(kind=Real8_) :: xRam, yRam

    logical :: DoTest, DoTestMe
    character(len=*), parameter :: NameSub='sort_mhd_lines'
    !------------------------------------------------------------------------
    call CON_set_do_test(NameSub, DoTest, DoTestMe)

    ! Clean slate:
    iPointBuff = 1
    iPointLine = 1
    MhdLines_IIV = 0.0

    if(DoTestMe) write(*,*)'IM:'//NameSub//'nLinesSWMF = ', nLinesSWMF
    
    NewLine: do iLine=1, nLinesSWMF
       ! Skip missing lines (i.e., inside MHD boundary)
       if (iLine<BufferLine_VI(1, iPointBuff)) then
          iEnd(iLine) = -1
          cycle NewLine
       end if

       do while(BufferLine_VI(1,iPointBuff)==iLine)
          ! As long as we're on the same line, sort those points.
          MhdLines_IIV(iLine, iPointLine, :) = BufferLine_VI(:, iPointBuff)
          iPointBuff = iPointBuff + 1
          iPointLine = iPointLine + 1
       end do
       
       ! Check for very long lines or open lines.
       if (iPointLine>nPointsMax-5) then
          write(*,*) NameSub, 'ERROR: nPointsMax exceeded.'
          ! This line is too long.  Why?
          if (abs(MhdLines_IIV(iLine, iPointLine-1, 5)) > 5.0) write(*,*) &
               'Open field line?  Z=',MhdLines_IIV(iLine,iPointLine-1,5)
          call CON_stop(NameSub//'nPointsMax exceeded.')
       endif

       ! Save length of current line, reset.
       iEnd(iLine) = iPointLine - 1
       iPointLine = 1
    end do NewLine

    MhdLines_IIV(:,:,3:5) = MhdLines_IIV(:,:,3:5)/6378100.0 !XYZ in R_E.

    ! Now, extend lines to ionosphere.  Fill in missing lines w/ dipole lines.
    nPoints = maxval(iEnd)+5
    iLon=1; iRad=1
    do iLine=1, nLinesSWMF
       ! If line is missing...
       if(iEnd(iLine)<0)then
          xRam = lz(iRad)*cos(phi(iLon))
          yRam = lz(iRad)*sin(phi(iLon))
          MhdLines_IIV(iLine,1,3) = xRam
          MhdLines_IIV(iLine,1,4) = yRam
          MhdLines_IIV(iLine,1,5) = 0.0
          call get_dipole_trace((/xRam, yRam, 0.0_Real8_/), nPoints-1,&
               MhdLines_IIV(iLine,2:nPoints,3), &
               MhdLines_IIV(iLine,2:nPoints,4), &
               MhdLines_IIV(iLine,2:nPoints,5) )
          ! Southern hemisphere?  Use simple symmetry.
          if(mod(iLine, 2) == 0) MhdLines_IIV(iLine,:,5) = &
               -1.0*MhdLines_IIV(iLine,:,5)
       else
          i = iEnd(iLine)
          !write(*,*)'Extending!'
          !write(*,*)'Adding ', nPoints-i, 'points.'
          !write(*,'(a,3f9.6)') '...from ', x(iLine,i),y(iLine,i),z(iLine,i)
          call get_dipole_trace((/MhdLines_IIV(iLine,i,3), &
               MhdLines_IIV(iLine,i,4),MhdLines_IIV(iLine,i,5)/), nPoints-i, &
               MhdLines_IIV(iLine, i+1:nPoints, 3), &
               MhdLines_IIV(iLine, i+1:nPoints, 4), &
               MhdLines_IIV(iLine, i+1:nPoints, 5) )
          if(mod(iLine, 2) == 0) MhdLines_IIV(iLine,i+1:nPoints,5) &
               = -1.*MhdLines_IIV(iLine,i+1:nPoints,5)
          !write(*,'(a,3f9.6)') 'Got to:',x(iLine,nPoints), y(iLine, nPoints), &
          !z(iLine,nPoints)
          iEnd(iLine) = nPoints
       end if
       ! Keep track of our lon&rad.
       if(mod(iLine, 2) == 0 )iRad=iRad+1
       if(iRad > nRextend) then
          iLon = iLon+1
          iRad = 1
       end if
    end do

    !write(*,*) MhdLines_IIV(1,:nPoints,3)
    !write(*,*) MhdLines_IIV(nLinesSWMF, :nPoints, 3)

    ! Save equatorial values, working backwards towards missing values.
    ! Note that the repeated longitude (0 and 2*pi) is skipped the 2nd time.
    do j=nT-1, 1, -1
       do i=nR+1, 1, -1
          ! Find corresponding trace.
          iLine = 2* ((nR+1)*(j-1) + i)
          ! Collect equatorial values.
          xEqSWMF(i,j) = MhdLines_IIV(iLine,1,3)
          yEqSWMF(i,j) = MhdLines_IIV(iLine,1,4)
          pEqSWMF(i,j) = MhdLines_IIV(iLine,1,TotalPres_)*1.0E9 !Pa->nPa
          nEqSWMF(i,j) = MhdLines_IIV(iLine,1,TotalRho_ )*1.67E-23 !amu->cm3
          ! For missing lines filled w/ dipole, grab last good values.
          if (iEnd(iLine) == -1) then
             pEqSWMF(i,j) = pEqSWMF(i+1,j)
             nEqSWMF(i,j) = nEqSWMF(i+1,j)
          end if
       end do
    end do
  
  end subroutine sort_mhd_lines
  !===========================================================================
  subroutine generate_flux
    ! Convert MHD density and pressure into flux.
    ! Methodology depends on MHD: single, multispecies, or multifluid.

    use ModIoUnit, ONLY: UnitTmp_
    use ModConst,  ONLY: cProtonMass, cElectronCharge, cPi
    use ModRamMain,ONLY: Real8_, Kp, F107, nT, nE, PathRamOut,&
                         EBND, WE, EKEV, TimeRamElapsed, TimeRamNow, &
                         Mu, M1, NameDistrib
    implicit none

    real, parameter :: cMass2Num = 1.0E6 * cProtonMass

    real(kind=Real8_) :: ratioHeH, ratioOH, fracH, fracHe, fracO
    real(kind=Real8_) :: factor, eCent, MhdPpar(4), MhdPper(4), dens, pres, ppar
    real(kind=Real8_) :: factor1, kappa, gamma1, gamma2, gamma3
    integer :: iT, iE, iPa
    character(len=100) :: NameFile

    ! Test Variables:
    logical :: DoTest, DoTestMe
    character(len=*), parameter :: NameSub = 'generate_flux'
    !------------------------------------------------------------------------
    call CON_set_do_test(NameSub, DoTest, DoTestMe)

    ! Convert mass density and pressure into number density and temp (ev).
    ! Separate species depending on type of simulation.    
    select case(TypeMhd)
    case('single')
       ! Use Young et al. (JGR, 1982, Vol. 87 No. A11) findings to
       ! split mass densit into number density for H, He, O.
       ! Start by using empirical relationships from Young et al.
       ! to obtain number density ratios (O/H and He/H) for given
       ! Kp and F10.7 flux.
       ratioOH = 4.5E-2 * exp(0.17*Kp + 0.01*F107)
       ratioHeH= 0.618182*ratioOH*exp(-0.24*Kp - 0.011*F107) + 0.011*ratioOH
       ! Use number dens. ratios to calculate % of each species to total.
       fracH = 1.0 / (1.0 + ratioHeH + ratioOH)
       fracHe= ratioHeH * fracH
       fracO = ratioOH  * fracH
       
       if (DoTestMe) then
          write(*,*) 'Fractions used: fracH, fracHe, fracO ='
          write(*,*) fracH, fracHe, fracO
       end if

       do iT=1, nT
          ! Convert kg/m^-3 to total #/cm^-3 for given species content.
          MhdDensPres_VII(1,iT,1) = MhdDensPres_VII(1,iT,1) / &
               ( cMass2Num * (fracH + 4*fracHe + 16*fracO) )
          ! Convert P to temp in eV.
          MhdDensPres_VII(2,iT,1) = MhdDensPres_VII(2,iT,1) / &
               ( cElectronCharge * 1.0E6 * MhdDensPres_VII(1,iT,1) )
          ! Set other species number density.
          MhdDensPres_VII(1,iT,2) = fracH  * MhdDensPres_VII(1,iT,1)
          MhdDensPres_VII(1,iT,3) = fracHe * MhdDensPres_VII(1,iT,1)
          MhdDensPres_VII(1,iT,4) = fracO  * MhdDensPres_VII(1,iT,1)
          ! All other temps the same in single fluid.
          MhdDensPres_VII(2,iT,2:) = MhdDensPres_VII(2,iT,1)
       end do
       MhdDensPres_VII(2,:,1) = MhdDensPres_VII(2,:,1)/7.0

    case ('anisoP')

       ratioOH = 4.5E-2 * exp(0.17*Kp + 0.01*F107)
       ratioHeH= 0.618182*ratioOH*exp(-0.24*Kp - 0.011*F107) + 0.011*ratioOH
       ! Use number dens. ratios to calculate % of each species to total                                                  
       fracH = 1.0 / (1.0 + ratioHeH + ratioOH)
       fracHe= ratioHeH * fracH
       fracO = ratioOH  * fracH

       if (DoTestMe) then
          write(*,*) 'Fractions used: fracH, fracHe, fracO ='
          write(*,*) fracH, fracHe, fracO
       end if

       do iT=1, nT
          ! Convert kg/m^-3 to total #/cm^-3 for given species content.    
          MhdDensPres_VII(1,iT,1) = MhdDensPres_VII(1,iT,1) / &
               ( cMass2Num * (fracH + 4*fracHe + 16*fracO) )
          ! Convert P to temp in eV.                 
          MhdDensPres_VII(2,iT,1) = MhdDensPres_VII(2,iT,1) / &
               ( cElectronCharge * 1.0E6 * MhdDensPres_VII(1,iT,1) )
          ! Set other species number density.            
          MhdDensPres_VII(1,iT,2) = fracH  * MhdDensPres_VII(1,iT,1)
          MhdDensPres_VII(1,iT,3) = fracHe * MhdDensPres_VII(1,iT,1)
          MhdDensPres_VII(1,iT,4) = fracO  * MhdDensPres_VII(1,iT,1)
          ! All other temps the same in single fluid.   
          MhdDensPres_VII(2,iT,2:) = MhdDensPres_VII(2,iT,1)

          ! convert P_par to T_par in eV        
          MhdDensPres_VII(3,iT,1) = MhdDensPres_VII(3,iT,1)/ &
               ( cElectronCharge * 1.0e6 * MhdDensPres_VII(1,iT,1))
          ! all other temps the same           
          MhdDensPres_VII(3,iT,2:)=MhdDensPres_VII(3,iT,1)
       end do
       ! electron temperature is lower     
       MhdDensPres_VII(2,:,1) = MhdDensPres_VII(2,:,1)/7.0
       MhdDensPres_VII(3,:,1) = MhdDensPres_VII(3,:,1)/7.0

    case('multiS')
       do iT=1, nT
          ! Save total mass density to calculate temperature.
          ! Do this with # of protons because that's how single fluid
          ! (yet multi species) MHD is actually tracking the fluid.
          MhdDensPres_VII(1,iT,1) = sum(MhdDensPres_VII(1,iT,2:4))
          ! Convert total and species mass density to number density.
          MhdDensPres_VII(1,iT,2) = MhdDensPres_VII(1,iT,2)!/ 1.0
          MhdDensPres_VII(1,iT,3) = MhdDensPres_VII(1,iT,3) / 4.0
          MhdDensPres_VII(1,iT,4) = MhdDensPres_VII(1,iT,4) /16.0
          ! Convert P to temp in eV.
          MhdDensPres_VII(2,iT,1) = MhdDensPres_VII(2,iT,1) / &
               ( cElectronCharge * 1.0E6 * MhdDensPres_VII(1,iT,1) )
          ! All other temps the same in single fluid.
          MhdDensPres_VII(2,iT,2:) = MhdDensPres_VII(2,iT,1)
       end do

    case('multiF')
       ! Convert total and species mass density to number density.
       MhdDensPres_VII(1,:,2) = MhdDensPres_VII(1,:,2)/(cMass2Num)
       MhdDensPres_VII(1,:,3) = MhdDensPres_VII(1,:,3)/(cMass2Num*4.0)
       MhdDensPres_VII(1,:,4) = MhdDensPres_VII(1,:,4)/(cMass2Num*16.0)
       MhdDensPres_VII(1,:,1) = sum(MhdDensPres_VII(1,:,2:4))
       
       ! Convert P to temp in eV.
       MhdDensPres_VII(2,:,1) = MhdDensPres_VII(2,:,1) / &
            ( cElectronCharge * 1.0E6 * MhdDensPres_VII(1,:,1) )
       MhdDensPres_VII(2,:,2) = MhdDensPres_VII(2,:,2) / &
            ( cElectronCharge * 1.0E6 * MhdDensPres_VII(1,:,2) )
       MhdDensPres_VII(2,:,3) = MhdDensPres_VII(2,:,3) / &
            ( cElectronCharge * 1.0E6 * MhdDensPres_VII(1,:,3) )
       MhdDensPres_VII(2,:,4) = MhdDensPres_VII(2,:,4) / &
            ( cElectronCharge * 1.0E6 * MhdDensPres_VII(1,:,4) )

    case('mult3F')
       ! Convert total and species mass density to number density (#/cm3)
       ! Helium slot is now solar wind protons.
       MhdDensPres_VII(1,:,2) = MhdDensPres_VII(1,:,2)/(cMass2Num)
       MhdDensPres_VII(1,:,3) = MhdDensPres_VII(1,:,3)/(cMass2Num)
       MhdDensPres_VII(1,:,4) = MhdDensPres_VII(1,:,4)/(cMass2Num*16.0)
       MhdDensPres_VII(1,:,1) = sum(MhdDensPres_VII(1,:,2:4))
       
       ! Convert Pa to temp in eV.
       MhdDensPres_VII(2,:,1) = MhdDensPres_VII(2,:,1) / &
            ( cElectronCharge * 1.0E6 * MhdDensPres_VII(1,:,1) )
       MhdDensPres_VII(2,:,2) = MhdDensPres_VII(2,:,2) / &
            ( cElectronCharge * 1.0E6 * MhdDensPres_VII(1,:,2) )
       MhdDensPres_VII(2,:,3) = MhdDensPres_VII(2,:,3) / &
            ( cElectronCharge * 1.0E6 * MhdDensPres_VII(1,:,3) )
       MhdDensPres_VII(2,:,4) = MhdDensPres_VII(2,:,4) / &
            ( cElectronCharge * 1.0E6 * MhdDensPres_VII(1,:,4) )

    case default
       call CON_stop(NameSub//' TypeMhd not recognized: '//TypeMhd)
    end select

    if(mod(TimeRamElapsed, 60.0_Real8_) .eq. 0.0) then
       ! Write boundary dens and pressure to file.
       write(NameFile,'(a,i6.6,a)')&
            PathRamOut//"bound_plasma_t",nint(TimeRamElapsed/60._Real8_),".out"
       open( UnitTmp_, FILE=NameFile, STATUS='replace')
       write(UnitTmp_,'(es13.5,i5,5i3)') &
            TimeRamElapsed, &
            TimeRamNow%iYear, TimeRamNow%iMonth, TimeRamNow%iDay, &
            TimeRamNow%iHour, TimeRamNow%iMinute, TimeRamNow%iSecond
       write(UnitTmp_, *) 'Units are Hours, cm-3, and eV'

       if (TypeMhd .eq. 'mult3F') then
          write(UnitTmp_, *) 'lt RhoE RhoH RhoSw RhoO pE pH pSw pO'
       elseif(TypeMhd .eq. 'anisoP')then
          write(UnitTmp_, *) 'lt RhoE RhoH RhoHe RhoO pE pH pHe pO pparE pparH pparHe pparO'
       else
          write(UnitTmp_, *) 'lt RhoE RhoH RhoHe RhoO pE pH pHe pO'
       endif

       do iT=1, nT
          if (TypeMhd .ne. 'anisoP')then
             write(UnitTmp_, '(i2.2, 8(1x, E13.6))') &
                  iT, MhdDensPres_VII(1,iT,1:4), MhdDensPres_VII(2,iT,1:4)
         else
             write(UnitTmp_, '(i2.2, 12(1x, E13.6))') &
                  iT,MhdDensPres_VII(1,iT,1:4),MhdDensPres_VII(2,iT,1:4),MhdDensPres_VII(3,iT,1:4)
          end if
       end do
       close(UnitTmp_)
    end if

    kappa = 3.
    gamma1 = 6.0    !gamma(kappa+1)  
    gamma2 = 1.3293 !gamma(kappa-0.5)  
    gamma3 = 0.886  ! gamma(1.5)
    factor1 = gamma1/gamma2/gamma3*sqrt(2*cPi)/(2*kappa-3)**1.5

    do iE=1, nE
       eCent = 1000.0 * Ekev(iE) ! Center of energy bin in eV.
       factor=4.0E6*Ekev(iE)     ! Unit conversion factor * eCent in KeV.
       do iT=1, nT
          if (TypeMhd .ne. 'anisoP')then
             if (NameDistrib .eq. 'MAXW') then

                ! Assuming a maxwellian distribution about MHD temperature, divide
                ! densities into energy bins and calculate fluxes.

                FluxBats_IIS(iE, iT, 1) = 1./sqrt(M1(1))*exp(-1.0*eCent/MhdDensPres_VII(2,iT,1))*&
                     factor * MhdDensPres_VII(1,iT,1) * &
                     (MhdDensPres_VII(2,iT,1)/1000.0_Real8_)**(-1.5)
                FluxBats_IIS(iE, iT, 2) = 1./sqrt(M1(2))*exp(-1.0*eCent/MhdDensPres_VII(2,iT,2))*&
                     factor * MhdDensPres_VII(1,iT,2) * &
                     (MhdDensPres_VII(2,iT,2)/1000.0_Real8_)**(-1.5)
                FluxBats_IIS(iE, iT, 3) = 1./sqrt(M1(3))*exp(-1.0*eCent/MhdDensPres_VII(2,iT,3))*&
                     factor * MhdDensPres_VII(1,iT,3) * &
                     (MhdDensPres_VII(2,iT,3)/1000.0_Real8_)**(-1.5)
                FluxBats_IIS(iE, iT, 4) = 1./sqrt(M1(4))*exp(-1.0*eCent/MhdDensPres_VII(2,iT,4))*&
                     factor * MhdDensPres_VII(1,iT,4) * &
                     (MhdDensPres_VII(2,iT,4)/1000.0_Real8_)**(-1.5)
             elseif(NameDistrib .eq.'KAPA')then
                ! assuming a kappa distribution
                
                FluxBats_IIS(iE,iT,1) = 1./sqrt(M1(1))*(1+1.0*eCent/(&
                     (kappa-1.5)*MhdDensPres_VII(2,iT,1)))**(-(kappa+1))*&
                     factor1*factor * MhdDensPres_VII(1,iT,1) * &
                     (MhdDensPres_VII(2,iT,1)/1000.0_Real8_)**(-1.5)
                FluxBats_IIS(iE,iT,2) = 1./sqrt(M1(2))*(1+1.0*eCent/(&
                     (kappa-1.5)*MhdDensPres_VII(2,iT,2)))**(-(kappa+1))*&
                     factor1*factor * MhdDensPres_VII(1,iT,2) * &
                     (MhdDensPres_VII(2,iT,2)/1000.0_Real8_)**(-1.5)
                FluxBats_IIS(iE,iT,3) = 1./sqrt(M1(3))*(1+1.0*eCent/(&
                     (kappa-1.5)*MhdDensPres_VII(2,iT,3)))**(-(kappa+1))*&
                     factor1*factor * MhdDensPres_VII(1,iT,3) * &
                     (MhdDensPres_VII(2,iT,3)/1000.0_Real8_)**(-1.5)
                FluxBats_IIS(iE,iT,4) = 1./sqrt(M1(4))*(1+1.0*eCent/(&
                     (kappa-1.5)*MhdDensPres_VII(2,iT,4)))**(-(kappa+1))*&
                     factor1*factor * MhdDensPres_VII(1,iT,4) * &
                     (MhdDensPres_VII(2,iT,4)/1000.0_Real8_)**(-1.5)
             else
                call CON_stop(NameSub//' NameDistribution not recognized: '//NameDistrib)
             end if
          else  ! anisotropic Mhd
             ! Tpar and Tper in eV; 
             MhdPpar = MhdDensPres_VII(3,iT,1:4)
             MhdPper = (MhdDensPres_VII(2,iT,1:4)*3-MhdPpar)/2.0
             if (NameDistrib .eq. 'MAXW')then
                ! assume a bi-maxwellian distribution                              
                do iPa=1, nPa
                   FluxBats_anis(iE,iPa,iT,1) = 1./sqrt(M1(1)) &
                        * exp(-1.0*eCent*MU(ipa)**2/MhdPpar(1) - 1.0*eCent*(1-mu(ipa)**2)/MhdPper(1)) &
                        * factor * MhdDensPres_VII(1,iT,1) &
                        /(MhdPper(1)/1000.0_Real8_*sqrt(MhdPpar(1)/1000.0_Real8_))
                   FluxBats_anis(iE,iPa,iT,2) = 1./sqrt(M1(2)) &
                        * exp(-1.0*eCent*MU(ipa)**2/MhdPpar(2) - 1.0*eCent*(1-MU(ipa)**2)/MhdPper(2)) &
                        * factor * MhdDensPres_VII(1,iT,2) &
                        /(MhdPper(2)/1000.0_Real8_*sqrt(MhdPpar(2)/1000.0_Real8_))
                   FluxBats_anis(iE,iPa,iT,3) = 1./sqrt(M1(3)) &
                        * exp(-1.0*eCent*MU(ipa)**2/MhdPpar(3) - 1.0*eCent*(1-MU(ipa)**2)/MhdPper(3)) &
                        * factor * MhdDensPres_VII(1,iT,3) &
                        /(MhdPper(3)/1000.0_Real8_*sqrt(MhdPpar(3)/1000.0_Real8_))
                   FluxBats_anis(iE,iPa,iT,4) = 1./sqrt(M1(4)) &
                        * exp(-1.0*eCent*MU(ipa)**2/MhdPpar(4) - 1.0*eCent*(1-MU(ipa)**2)/MhdPper(4)) &
                        * factor * MhdDensPres_VII(1,iT,4) &
                        /(MhdPper(4)/1000.0_Real8_*sqrt(MhdPpar(4)/1000.0_Real8_))
                end do
             elseif(NameDistrib .eq. 'KAPA')then
                ! assume a bi-kappa distribution 
                do iPa=1, nPa
                   FluxBats_anis(iE,iPa,iT,1) = 1./sqrt(M1(1)) * &
                        (1+1.0*eCent*MU(ipa)/((kappa-1.5)*MhdPpar(1) ) + &
                        1.0*eCent*(1-MU(ipa)**2)/((kappa-1.5)*MhdPper(1)))**(-(kappa+1))*&
                        factor1*factor * MhdDensPres_VII(1,iT,1)  &
                        /(MhdPper(1)/1000.0_Real8_*sqrt(MhdPpar(1)/1000.0_Real8_))
                   FluxBats_anis(iE,iPa,iT,2) = 1./sqrt(M1(2)) * &
                        (1+1.0*eCent*MU(ipa)/((kappa-1.5)*MhdPpar(2) ) + &
                        1.0*eCent*(1-MU(ipa)**2)/((kappa-1.5)*MhdPper(2)))**(-(kappa+1))*&
                        factor1*factor * MhdDensPres_VII(1,iT,2)  &
                        /(MhdPper(2)/1000.0_Real8_*sqrt(MhdPpar(2)/1000.0_Real8_))
                   FluxBats_anis(iE,iPa,iT,3) = 1./sqrt(M1(3)) * &
                        (1+1.0*eCent*MU(ipa)/((kappa-1.5)*MhdPpar(3) ) + &
                        1.0*eCent*(1-MU(ipa)**2)/((kappa-1.5)*MhdPper(3)))**(-(kappa+1))*&
                        factor1*factor * MhdDensPres_VII(1,iT,3)  &
                        /(MhdPper(3)/1000.0_Real8_*sqrt(MhdPpar(3)/1000.0_Real8_))
                   FluxBats_anis(iE,iPa,iT,4) = 1./sqrt(M1(4)) * &
                        (1+1.0*eCent*MU(ipa)/((kappa-1.5)*MhdPpar(4) ) + &
                        1.0*eCent*(1-MU(ipa)**2)/((kappa-1.5)*MhdPper(4)))**(-(kappa+1))*&
                        factor1*factor * MhdDensPres_VII(1,iT,4)  &
                        /(MhdPper(4)/1000.0_Real8_*sqrt(MhdPpar(4)/1000.0_Real8_))
                end do
             else
                call CON_stop(NameSub//' NameDistribution not recognized: '//NameDistrib)
             end if
          end if

       end do
    end do
    
    ! Remove ridiculously small values.
    if (TypeMhd .ne. 'anisoP')then
       where(FluxBats_IIS .lt. 1.0E-30) FluxBats_IIS = 0.0
    else
       where(FluxBats_anis .lt. 1.0E-30) FluxBats_anis = 0.0
    end if

    ! If using two hydrogen species (case of Mult3F), one is saved in 
    ! helium's spot.  Combine H+ fluxes and set He flux to small fraction.
    if (TypeMhd .eq. 'mult3F') then
       FluxBats_IIS(:,:,2) = FluxBats_IIS(:,:,2) + FluxBats_IIS(:,:,3)
       FluxBats_IIS(:,:,3) = 0.01 * FluxBats_IIS(:,:,2) ! 1% of H+ flux.
    end if

    if(DoTestMe)call write_FluxGM
    
    ! With the flux array stored in the module, coupling is complete.

  end subroutine generate_flux

  !===========================================================================
  subroutine write_FluxGM
    ! Quickly write out flux from GM to files for stand-alone RAM.
    use ModRamMain, ONLY: nT, nE, TimeRamElapsed,PathRamOut
    use ModIoUnit,      ONLY: UnitTmp_
    implicit none
    
    integer :: iS, iT, nFile, iPa
    character(len=100) :: NameFile
    character(len=35)  :: StringFormat

    character(len=*), parameter :: NameSub = "write_FluxGM"
    !------------------------------------------------------------------------
    nFile = nint(TimeRamElapsed/300.0)
    write(StringFormat,'(a,i2,a)') '(f8.2, 1x, f7.2, ', nE, '(1x, 1pE11.4))'
    ! Write one file for each species.
    do iS=1,4
       write(NameFile,'(a,i4.4,a,i1.1,a)')  &
            PathRamOut//"sep_05_",nFile,"_",iS,".swf"
       open(UnitTmp_, FILE=NameFile, STATUS='replace')
       
       write(UnitTmp_, *) &
            'Flux file for TimeRam, iSpecies = ', TimeRamElapsed, iS
       do iT=1, nT
          if(TypeMhd .ne. 'anisoP')then
             write(UnitTmp_,StringFormat) 1.0, iT-1.0, FluxBats_IIS(:,iT,iS)
          else
             do iPa=1,nPa
                write(UnitTmp_,StringFormat) 1.0, iT-1.0, FluxBats_anis(:,ipa,iT,iS)
             end do
          end if
       end do
       write(UnitTmp_,*)'Necessary Footer.'
       close(UnitTmp_)
    end do
  end subroutine write_FluxGM

  !===========================================================================
  function divMaxwellian(eMin, eMax, Dens, Temp)
    ! Enter start and stop of energy window (in eV), total density of plasma,
    ! and total plasma temperature (again, in eV) to receive new density based 
    ! on energy window for a Maxwellian particle distribution.
    
    use ModRamMain, ONLY: Real8_
    use ModConst,   ONLY: cElectronCharge, cPi
    implicit none

    ! Arguments:
    real(kind=Real8_) :: divMaxwellian
    real(kind=Real8_), intent(in) :: Temp, Dens
    real(kind=Real8_), intent(in) :: eMin, eMax

    real(kind=Real8_) :: dE, factor1, factor2, energy
    integer           :: i
    !------------------------------------------------------------------------
    ! Set starting and delta energy.
    energy = eMin
    dE = (eMax - eMin) / 1000.0
 
    ! Do Riemann sum of Maxwellian distribution for
    ! given energy window.
    divMaxwellian = 0.0
    do i=1, 1000
       ! Handle exponent part of Maxwellian.
       ! Prevent underflows in the exponent.
       factor1 = (-1 * energy) / Temp
       if (factor1 .lt. -750.0) then
          factor1 = 0.0
       else 
          factor1 = exp(factor1)
       end if

       ! Calculate non-exponent portion of Maxwellian.
       factor2 = 2.0 * sqrt( energy / (cPi * temp**3) )

       ! Add this portion to the density sum.
       divMaxwellian = divMaxwellian + dens * factor1 * factor2 * dE

       energy = energy + dE
       
    end do

    return
  end function divMaxwellian

  !===========================================================================

end module ModRamCouple
!==============================================================================
