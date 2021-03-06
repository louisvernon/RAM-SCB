SUBROUTINE metrics

  !****************************************************************************
  ! Computes physical quantities at the end of the calculation
  ! Author: S. Zaharia, 2003-2011
  ! Copyright (c) 2016, Los Alamos National Security, LLC
  ! All rights reserved.
  !****************************************************************************

  USE nrtype
  USE Module1
  USE ezcdf

  IMPLICIT NONE

  INTERFACE EZ_Spline_3D_derivatives
     SUBROUTINE Spline_coord_derivs(x_1, x_2, x_3, f_input, derivsX1, derivsX2, derivsX3)
       USE Module1
       USE EZspline_obj ! import the modules
       USE EZspline  

       IMPLICIT NONE
       INTEGER, PARAMETER :: r8 = DP
       !       REAL(r8), PARAMETER :: twopi = 6.2831853071795862320_r8
       REAL(r8), DIMENSION(:), INTENT(IN) :: x_1
       REAL(r8), DIMENSION(:), INTENT(IN) :: x_2
       REAL(r8), DIMENSION(:), INTENT(IN) :: x_3 ! independent variables
       REAL(r8), DIMENSION(:,:,:), INTENT(IN) :: f_input
       REAL(r8), DIMENSION(:,:,:), INTENT(OUT) :: derivsX1, derivsX2, derivsX3 
     END SUBROUTINE Spline_coord_derivs
  END INTERFACE

  INTEGER :: i, j, k, nzd1, nzd2, nzd3, nzd4, nthe0, nthe1, id, ierr, idealerr, ncdfId
  INTEGER, DIMENSION(3) :: dimlens = (/1, 1, 1/)
  REAL(DP) :: yyp, bju, bjd, normDivJCrossB, normCurlJCrossB, volume, region1FAC, region2FAC, &
       totalCROSS, dstComputed, EAlpha, EBeta, gradPhiIonoGradAlpha, gradPhiIonoGradBeta
  REAL(DP) :: metricDif(nthe, nzeta), metricDif2(nthe, npsi)
  REAL(DP), DIMENSION(nthe,npsi,nzeta) :: alphaTerm, psiTerm, derivNU1, derivNU2
  REAL(DP), DIMENSION(nthe,npsi,nzeta) :: derivXTheta, derivXRho, derivXZeta, &
       & derivYTheta, derivYRho, derivYZeta, derivZTheta, derivZRho, derivZZeta, &
       & gradRhoX, gradRhoY, gradRhoZ, gradZetaX, gradZetaY, gradZetaZ, gradThetaX, &
       gradThetaY, gradThetaZ, gradThetaSq, derivBsqRho, derivBsqZeta
  ! gradRhoSq, gradRhoGradZeta are global
  REAL(DP), DIMENSION(nthe,npsi,nzeta) :: jGradRhoPartialTheta, derivjGradRhoPartialTheta, &
       & jGradRhoPartialZeta, derivjGradRhoPartialZeta, jGradRho, jGradRhoFactor, jGradZetaPartialRho, &
       & derivjGradZetaPartialRho, jGradZetaPartialTheta, derivjGradZetaPartialTheta, jGradZeta, &
       & jGradZetaFactor, jGradThetaPartialRho, derivjGradThetaPartialRho, jGradThetaPartialZeta, &
       & derivjGradThetaPartialZeta, jGradTheta, jGradThetaFactor, phiToroid, derivPhiRho, derivPhiZeta, &
       & derivPhiTheta, dPpardZeta, dPpardRho, dPpardTheta, generateFAC, generateFACPAlpha, generateFACPPsi !, &
 !      distanceAlongLine

  !  Compute metrics after the solution has converged
  !  xx is the radius in cylindrical coordinate system
  !  yy is the toroidal angle

  DO  j = 1,npsi
     DO  i = 1,nthe
        DO  k = 2,nzeta
           xx(i,j,k) = SQRT(x(i,j,k)**2 + y(i,j,k)**2)
           yy(i,j,k) = x(i,j,k) / xx(i,j,k)
           yyp = yy(i,j,k)
           yy(i,j,k) = ACOS(yyp)
        END DO
        !  avoid k = 2 for y near zero so that phi can be negative, but small
        IF(y(i,j,2) < 0.0) yy(i,j,2)=-yy(i,j,2)
        DO  k=3,nzeta
           IF(y(i,j,k) < 0.0) yy(i,j,k)=twopi_d-yy(i,j,k)
        END DO
        DO  k=2,nzeta
           dela(k) = alfa(i,j,k) - yy(i,j,k)
        END DO
        dela(1) = dela(nzeta)
        dela(nzetp) = dela(2)
        xx(i,j,1) = xx(i,j,nzeta)
        xx(i,j,nzetp) = xx(i,j,2)
        yy(i,j,1) = alfa(i,j,1) - dela(1)
        yy(i,j,nzetp) = alfa(i,j,nzetp) - dela(nzetp)
     END DO
  END DO

  CALL Spline_coord_derivs(thetaVal, rhoVal, zetaVal, x(1:nthe, 1:npsi, 1:nzeta), derivXTheta, &
       & derivXRho, derivXZeta)
  CALL Spline_coord_derivs(thetaVal, rhoVal, zetaVal, y(1:nthe, 1:npsi, 1:nzeta), derivYTheta, &
       & derivYRho, derivYZeta)
  CALL Spline_coord_derivs(thetaVal, rhoVal, zetaVal, z(1:nthe, 1:npsi, 1:nzeta), derivZTheta, &
       & derivZRho, derivZZeta) 

  ! Now we have all the point derivatives
  ! Time to build the Jacobian

  jacobian = derivXRho * (derivYZeta * derivZTheta - derivYTheta * derivZZeta) + derivXZeta * &
       & (derivYTheta * derivZRho - derivYRho * derivZTheta) + derivXTheta * &
       & (derivYRho * derivZZeta - derivYZeta * derivZRho)

  DO k = 1, nzeta
     DO j = 1, npsi
        bX(:,j,k) = 1._dp/jacobian(:,j,k) * f(j) * fzet(k) * derivXTheta(:,j,k)
        bY(:,j,k) = 1._dp/jacobian(:,j,k) * f(j) * fzet(k) * derivYTheta(:,j,k)
        bZ(:,j,k) = 1._dp/jacobian(:,j,k) * f(j) * fzet(k) * derivZTheta(:,j,k)
     END DO
  END DO

  gradRhoX = (derivYZeta * derivZTheta - derivYTheta * derivZZeta) / jacobian
  gradRhoY = (derivZZeta * derivXTheta - derivZTheta * derivXZeta) / jacobian
  gradRhoZ = (derivXZeta * derivYTheta - derivXTheta * derivYZeta) / jacobian

  gradZetaX = (derivYTheta * derivZRho - derivYRho * derivZTheta) / jacobian
  gradZetaY = (derivZTheta * derivXRho - derivZRho * derivXTheta) / jacobian
  gradZetaZ = (derivXTheta * derivYRho - derivXRho * derivYTheta) / jacobian

  gradThetaX = (derivYRho * derivZZeta - derivYZeta * derivZRho) / jacobian
  gradThetaY = (derivZRho * derivXZeta - derivZZeta * derivXRho) / jacobian
  gradThetaZ = (derivXRho * derivYZeta - derivXZeta * derivYRho) / jacobian


  gradRhoSq = gradRhoX**2 + gradRhoY**2 + gradRhoZ**2
  gradRhoGradZeta = gradRhoX * gradZetaX + gradRhoY * gradZetaY + gradRhoZ * gradZetaZ
  gradRhoGradTheta = gradRhoX * gradThetaX + gradRhoY * gradThetaY + gradRhoZ * gradThetaZ

  gradThetaSq = gradThetaX**2 + gradThetaY**2 + gradThetaZ**2
  gradThetaGradZeta = gradThetaX * gradZetaX + gradThetaY * gradZetaY + gradThetaZ * gradZetaZ

  gradZetaSq = gradZetaX**2 + gradZetaY**2 + gradZetaZ**2


  InducedE: IF (rank == 0 .AND. iInducedE /= 0) THEN
     DO k = 2, nzeta
        DO j = 1, npsi
           DO i = nThetaEquator, nThetaEquator ! Only equatorial plane for now
              IF (iHour > iHourBegin) THEN
                 EAlpha = - dAlphadT(i,j,k) * gradRhoGradZeta(i,j,k)*f(j)*fzet(k) + &
                      dBetadT(i,j,k)*gradRhoSq(i,j,k) * f(j)**2 
                 EBeta = -dAlphadT(i,j,k)*gradZetaSq(i,j,k) * fzet(k)**2 + &
                      dBetadT(i,j,k) * gradRhoGradZeta(i,j,k) ! Verify this
                 EXInd(i,j,k) = derivXRho(i,j,k)*EAlpha/f(j) + derivXZeta(i,j,k)*EBeta/fzet(k)
                 EYInd(i,j,k) = derivYRho(i,j,k)*EAlpha/f(j) + derivYZeta(i,j,k)*EBeta/fzet(k)
                 EZInd(i,j,k) = 0._dp ! zero for N-S symmetry !C derivZRho(i,j,k)*EAlpha/f(j) + derivZZeta(i,j,k)*EBeta/fzet(k)
              ELSE
                 EXInd = 0._dp
                 EYInd = 0._dp
                 EZInd = 0._dp
              END IF
           END DO
        END DO
     END DO
     ! Periodicity
     EXInd(:,:,1) = EXInd(:,:,nzeta)
     EYInd(:,:,1) = EYInd(:,:,nzeta)
     EZInd(:,:,1) = EZInd(:,:,nzeta)
     EXInd(:,:,nzetp) = EXInd(:,:,2)
     EYInd(:,:,nzetp) = EYInd(:,:,2)
     EZInd(:,:,nzetp) = EZInd(:,:,2)
  END IF InducedE

  ConvectionE:     IF (rank==0 .AND. iConvE == 1) THEN
     DO k = 2, nzeta
        DO j = 1, npsi
           DO i = 1, nthe
              gradPhiIonoGradAlpha = dPhiIonodAlpha(j,k) * gradRhoSq(i,j,k) * f(j)**2 + &
                   dPhiIonodBeta(j,k) * gradRhoGradZeta(i,j,k) * f(j)*fzet(k)
              gradPhiIonoGradBeta = dPhiIonodAlpha(j,k) * gradRhoGradZeta(i,j,k) * f(j)*fzet(k) + &
                   dPhiIonodBeta(j,k)*gradZetaSq(i,j,k) * fzet(k)**2
              EXConv(i,j,k) = - (derivXRho(i,j,k)*gradPhiIonoGradAlpha/f(j) + derivXZeta(i,j,k)*gradPhiIonoGradBeta/fzet(k))
              EYConv(i,j,k) = - (derivYRho(i,j,k)*gradPhiIonoGradAlpha/f(j) + derivYZeta(i,j,k)*gradPhiIonoGradBeta/fzet(k))
              EZConv(i,j,k) = - (derivZRho(i,j,k)*gradPhiIonoGradAlpha/f(j) + derivZZeta(i,j,k)*gradPhiIonoGradBeta/fzet(k))
           END DO
        END DO
     END DO
     ! Periodicity
     EXConv(:,:,1) = EXConv(:,:,nzeta)
     EYConv(:,:,1) = EYConv(:,:,nzeta)
     EZConv(:,:,1) = EZConv(:,:,nzeta)
     EXConv(:,:,nzetp) = EXConv(:,:,2)
     EYConv(:,:,nzetp) = EYConv(:,:,2)
     EZConv(:,:,nzetp) = EZConv(:,:,2)
  END IF ConvectionE


     ! B field squared is obtained now, then the B field bf; in the following, i, j, k can be 
     ! taken over the full domain because we have all the required quantities everywhere;
     ! thus, extrapolation for Bfield is not necessary anymore

     DO  k = 1,nzeta
        DO  j = 1,npsi
           DO  i = 1,nthe
              bsq(i,j,k) = (gradRhoSq(i,j,k) * gradZetaSq(i,j,k) - gradRhoGradZeta(i,j,k) **2) & 
                   & * (f(j) * fzet(k)) **2 
              bf(i,j,k) = SQRT(bsq(i,j,k))
           END DO
        END DO
     END DO

     CALL Spline_coord_derivs(thetaVal, rhoVal, zetaVal, bsq(1:nthe, 1:npsi, 1:nzeta), &
          & dBsqdTheta, derivBsqRho, derivBsqZeta)  

     IF (isotropy /= 1) THEN 

        CALL Spline_coord_derivs(thetaVal, rhoVal, zetaVal, ppar(1:nthe,1:npsi,1:nzeta), &
             dPpardTheta, dPpardRho, dPpardZeta)
        DO k = 1, nzeta
           dPpardAlpha(:,:,k) = 1./fzet(k) * dPpardZeta(:,:,k)
        END DO
        DO j = 1, npsi
           dPpardPsi(:,j,:) = 1./f(j) * dPpardRho(:,j,:)
        END DO
     END IF

     ! Field-aligned current density; = 0 at equator

     ! 1). Computation using integration along the field line
     ! B \cdot grad(sigma*bj/B) = grad(B^2)xB \cdot grad(P)/ (sigma*B^4)

     DO   k = 1,nzeta
        DO  j = 1,npsi
           !     psiTerm = B x grad (psi) dot grad (B^2)
           psiTerm(:,j,k) = bsq(1:nthe,j,k) * derivBsqZeta(:,j,k) + dBsqdTheta(:,j,k) &
                & * (gradRhoSq(:,j,k) * gradThetaGradZeta(:,j,k) - &
                & gradRhoGradTheta(:,j,k) * gradRhoGradZeta(:,j,k)) * (f(j)*fzet(k))**2
           psiTerm(:,j,k) = psiTerm(:,j,k) / fzet(k) ! OK 

           IF (isotropy == 1) THEN ! Only for the isotropic case
              ! Now geodesic curvature 
              curvaturePsi(1:nthe,j,k) = (2._dp * dpdAlpha(1:nthe,j,k) + derivBsqZeta(1:nthe,j,k) * &
                   & 1._dp/fzet(k)) / bsq(1:nthe,j,k) + dBsqdTheta(1:nthe,j,k) * 1._dp / bsq(1:nthe,j,k)**2 * &
                   & (gradRhoSq(1:nthe,j,k) * gradThetaGradZeta(1:nthe,j,k) - &
                   gradRhoGradTheta(1:nthe,j,k) * gradRhoGradZeta(1:nthe,j,k)) * (f(j)**2) * fzet(k)

              curvatureGradPsi(1:nthe,j,k) = 1./bsq(1:nthe,j,k) * (dpdPsi(1:nthe,j,k) + 0.5 * &
                   & derivBsqRho(1:nthe,j,k) * 1./f(j) + gradRhoGradZeta(1:nthe,j,k)/gradRhoSq(1:nthe,j,k) * &
                   & fzet(k)/f(j) * (dpdAlpha(1:nthe,j,k) + 0.5 * derivBsqZeta(1:nthe,j,k) * 1./fzet(k)) + &
                   & 0.5 * gradRhoGradTheta(1:nthe,j,k)/gradRhoSq(1:nthe,j,k) * 1./f(j) * &
                   & dBsqdTheta(1:nthe,j,k))
              radialCurvature(1:nthe,j,k) = curvatureGradPsi(1:nthe,j,k) * f(j) * SQRT(gradRhoSq(1:nthe,j,k))

           END IF

           gradPsiGradAlpha(1:nthe,j,k) = f(j) * fzet(k) * gradRhoGradZeta(1:nthe,j,k)
           gradAlphaSq(1:nthe,j,k) = fzet(k)**2 * gradZetaSq(1:nthe,j,k)

           !     alphaTerm = B x grad (alfa) dot grad (B^2)
           alphaTerm(:,j,k) = - bsq(1:nthe,j,k) * derivBsqRho(:,j,k) + dBsqdTheta(:,j,k) &
                * (gradRhoGradZeta(:,j,k) * gradThetaGradZeta(:,j,k) - &
                & gradRhoGradTheta(:,j,k) * gradZetaSq(:,j,k)) * (f(j)*fzet(k))**2
           alphaTerm(:,j,k) = alphaTerm(:,j,k) / f(j) ! OK
        END DO
     END DO

     nthe1 = nThetaEquator + 1

     FAC_Isotropy_Choice:  IF (isotropy == 1) THEN  ! Isotropic case
        DO  j       = 2, npsim
           DO  k    = 1, nzeta       
              bju = 0._dp
              bjd = 0._dp
              iLoop:  DO  i = nthe1, nthe
                 ! Now the factors 1/(f*fzet) have been added correctly
                 generateFACPAlpha(i,j,k) = 1._dp/(f(j)*fzet(k)) * jacobian(i,j,k) / bsq(i,j,k) **2 * &
                      (dPdAlpha(i,j,k)  * alphaTerm(i,j,k) - 2._dp*dPdAlpha(i,j,k)*dPdPsi(i,j,k)*bsq(i,j,k)) 
                 generateFACPPsi(i,j,k) = 1._dp/(f(j)*fzet(k)) * jacobian(i,j,k) / bsq(i,j,k) **2 * &
                      (dpdPsi(i,j,k) * psiTerm(i,j,k) + 2._dp*dPdAlpha(i,j,k)*dPdPsi(i,j,k)*bsq(i,j,k))
                 generateFAC(i,j,k) = generateFACPAlpha(i,j,k) + generateFACPPsi(i,j,k)

                 bju = bju + generateFAC(i,j,k) * dt
                 bj(i, j, k)      = bju * bf(i, j, k)

                 id = nthe - i + 1
                 generateFACPAlpha(id,j,k) = 1._dp/(f(j)*fzet(k)) * jacobian(id,j,k) / bsq(id,j,k) **2 * &
                      dpdAlpha(id,j,k)  * alphaTerm(id,j,k)
                 generateFACPPsi(id,j,k) = 1._dp/(f(j)*fzet(k)) * jacobian(id,j,k) / bsq(id,j,k) **2 * &
                      dpdPsi(id,j,k) * psiTerm(id,j,k) 
                 generateFAC(id,j,k) = generateFACPAlpha(id,j,k) + generateFACPPsi(id,j,k)

                 bjd = bjd + generateFAC(id,j,k) * dt
                 bj(id, j, k)             = bjd * bf(id, j, k)
              END DO iLoop
           END DO
        END DO
     ELSE ! Anisotropic pressure case
        DO  j       = 2, npsim
           DO  k    = 1, nzeta ! nZetaMidnight
              bju = 0._dp
              bjd = 0._dp
              !        bj(nthe0,j,k)=bju*bf(nthe0,j,k)/sigma(nthe0,j,k)
              DO  i = nthe1, nthe
                 bju = bju + 1._dp/(2.*f(j)*fzet(k)) * dt * jacobian(i,j,k) / &
                      (sigma(i,j,k) * bsq(i,j,k) **2) * &
                      ((dPperdPsi(i,j,k) + dPpardPsi(i,j,k))* psiTerm(i,j,k) + &
                      (dPperdAlpha(i,j,k) + dPpardAlpha(i,j,k)) * alphaTerm(i,j,k))
                 bj(i, j, k)      = bju * bf(i, j, k) / sigma(i,j,k)

                 id = nthe - i + 1
                 bjd = bjd + 1._dp/(2.*f(j)*fzet(k)) * dt * jacobian(i,j,k) / &
                      (sigma(i,j,k) * bsq(i,j,k) **2) * &
                      ((dPperdPsi(i,j,k) + dPpardPsi(i,j,k))* psiTerm(i,j,k) + &
                      (dPperdAlpha(i,j,k) + dPpardAlpha(i,j,k)) * alphaTerm(i,j,k))
                 bj(id, j, k)             = bjd * bf(id, j, k) / sigma(i,j,k)
              END DO
           END DO
        END DO
     END IF FAC_Isotropy_Choice

     ! Now compute TOTAL field-aligned current in the Regions 1 and 2 at i = nthe - 1
     region1FAC = 0._dp
     region2FAC = 0._dp
     DO j = 2, npsi-1
        DO k = 2, nZetaMidnight
           ! Area element is dS = jacobian * drho * dzeta * |grad theta|
           IF (bj(2,j,k) < 0) THEN   ! Region 1
              region1FAC = region1FAC + bj(2,j,k)/bf(2,j,k) * f(j) * fzet(k) * &
                   dr * dpPrime
           ELSE                      ! Region 2
              region2FAC = region2FAC + bj(2,j,k)/bf(2,j,k) * f(j) * fzet(k) * &
                   dr * dpPrime
           END IF
        END DO
     END DO


     ! Now time for 2nd calculation of field-aligned current, and also for calculation of 
     ! toroidal current

     ! First, DIRECT computation of the field-aligned current jparDirect

     ! j dot gradRho

     DO j = 1, npsi
        DO k = 1, nzeta
           jGradRhoPartialTheta(:,j,k) = jacobian(:,j,k) * f(j) * fzet(k) * &
                (gradRhoSq(:,j,k) * gradThetaGradZeta(:,j,k) - gradRhoGradTheta(:,j,k) * &
                gradRhoGradZeta(:,j,k))
           jGradRhoPartialZeta(:,j,k) = jacobian(:,j,k) * f(j) * fzet(k) * &
                (gradRhoSq(:,j,k) * gradZetaSq(:,j,k) - gradRhoGradZeta(:,j,k) **2)
        END DO
     END DO

     ! CALL Spline_coord_derivs(thetaVal, rhoVal, zetaVal, jGradRhoPartialTheta, &
     !      & derivjGradRhoPartialTheta, derivNU1, derivNU2)
     ! CALL Spline_coord_derivs(thetaVal, rhoVal, zetaVal, jGradRhoPartialZeta, &
     !      & derivNU1, derivNU2, derivjGradRhoPartialZeta)

     !  jGradRho = 1._dp / jacobian * (derivjGradRhoPartialTheta + derivjGradRhoPartialZeta)

     IF (isotropy == 1) THEN 
        DO j = 1, npsi
           jGradRho(:,j,1:nzeta) = - 1._dp / f(j) * dpdAlpha(:,j,1:nzeta)
        END DO
     ELSE       ! anisotropic pressure case
        DO i = 1, nthe
           DO j = 1, npsi
              DO k = 1, nzeta
                 jGradRho(i,j,k) = 1._dp / f(j) * (-1./sigma(i,j,k) * dPperdAlpha(i,j,k) &
                      - 1./(sigma(i,j,k)*bsq(i,j,k)) * f(j)**2 * fzet(k) * (gradRhoSq(i,j,k)* &
                      gradThetaGradZeta(i,j,k) - gradRhoGradTheta(i,j,k)*gradRhoGradZeta(i,j,k)) * &
                      (dPperdTheta(i,j,k) + (1.-sigma(i,j,k))*0.5*dBsqdTheta(i,j,k)) - &
                      (1.-sigma(i,j,k))/sigma(i,j,k)*0.5*dBsqdAlpha(i,j,k))
              END DO
           END DO
        END DO
     END IF

     ! j dot gradZeta

     DO j = 1, npsi
        DO k = 1, nzeta
           jGradZetaPartialRho(:,j,k) = jacobian(:,j,k) * f(j) * fzet(k) * &
                (gradRhoGradZeta(:,j,k) **2 - gradRhoSq(:,j,k) * &
                gradZetaSq(:,j,k))
           jGradZetaPartialTheta(:,j,k) = jacobian(:,j,k) * f(j) * fzet(k) * &
                (gradRhoGradZeta(:,j,k) * gradThetaGradZeta(:,j,k) - gradRhoGradTheta(:,j,k) * &
                & gradZetaSq(:,j,k))
        END DO
     END DO

     !  CALL Spline_coord_derivs(thetaVal, rhoVal, zetaVal, jGradZetaPartialRho, &
     !       & derivNU1, derivjGradZetaPartialRho, derivNU2)
     !  CALL Spline_coord_derivs(thetaVal, rhoVal, zetaVal, jGradZetaPartialTheta, &
     !       & derivjGradZetaPartialTheta, derivNU1, derivNU2)

     ! jGradZeta = 1._dp / jacobian * (derivjGradZetaPartialRho + derivjGradZetaPartialTheta)

     IF (isotropy == 1) THEN
        DO k = 1, nzeta
           jGradZeta(:,:,k) = 1._dp / fzet(k) * dpdPsi(:,:,k)
        END DO
     ELSE                    ! anisotropic pressure case
        DO i = 1, nthe
           DO j = 1, npsi
              DO k = 1, nzeta
                 jGradZeta(i,j,k) = 1._dp/fzet(k) * (1./sigma(i,j,k) * dPperdPsi(i,j,k) &
                      - 1./(sigma(i,j,k)*bsq(i,j,k)) * f(j) * fzet(k)**2 * (gradRhoGradZeta(i,j,k)* &
                      gradThetaGradZeta(i,j,k) - gradRhoGradTheta(i,j,k)*gradZetaSq(i,j,k)) * &
                      (dPperdTheta(i,j,k) + (1.-sigma(i,j,k))*0.5*dBsqdTheta(i,j,k)) + &
                      (1.-sigma(i,j,k))/sigma(i,j,k)*0.5*dBsqdPsi(i,j,k))
              END DO
           END DO
        END DO

     END IF

     ! j dot gradTheta

     DO j = 1, npsi
        DO k = 1, nzeta
           jGradThetaPartialRho(:,j,k) = jacobian(:,j,k) * f(j) * fzet(k) * &
                (gradRhoGradTheta(:,j,k) * gradRhoGradZeta(:,j,k) - gradRhoSq(:,j,k) * &
                gradThetaGradZeta(:,j,k))
           jGradThetaPartialZeta(:,j,k) = jacobian(:,j,k) * f(j) * fzet(k) * &
                (gradRhoGradTheta(:,j,k) * gradZetaSq(:,j,k) - gradRhoGradZeta(:,j,k) * &
                & gradThetaGradZeta(:,j,k))
        END DO
     END DO

     CALL Spline_coord_derivs(thetaVal, rhoVal, zetaVal, jGradThetaPartialRho, &
          & derivNU1, derivjGradThetaPartialRho, derivNU2)
     CALL Spline_coord_derivs(thetaVal, rhoVal, zetaVal, jGradThetaPartialZeta, &
          & derivNU1, derivNU2, derivjGradThetaPartialZeta)

     jGradTheta = 1._dp / jacobian * (derivjGradThetaPartialRho + derivjGradThetaPartialZeta)

     ! Now final stage of direct computation of the field-aligned current

     jGradRhoFactor = gradRhoGradZeta * gradThetaGradZeta - gradZetaSq * gradRhoGradTheta
     jGradZetaFactor = gradRhoGradTheta * gradRhoGradZeta - gradThetaGradZeta * gradRhoSq
     jGradThetaFactor = gradRhoSq * gradZetaSq - gradRhoGradZeta **2

     DO j = 1, npsi
        DO k = 1, nzeta
           jParDirect(:,j,k) = 1._dp/ bf(1:nthe, j, k) * jacobian(:,j,k) * f(j) &
                & * fzet(k) * &
                & (jGradRho(:,j,k) * jGradRhoFactor(:,j,k) + jGradZeta(:,j,k) &
                & * jGradZetaFactor(:,j,k) + &
                & jGradTheta(:,j,k) * jGradThetaFactor(:,j,k))
        END DO
     END DO

     ! Now the southern current has the wrong sign, since B is outward in
     ! the southward hemisphere, and we just computed |JdotB|/B

     DO i = 1, nThetaEquator-1
        jParDirect(i,:,:) = -jParDirect(i,:,:)
     END DO


     ! Calculating toroidal current when equilibrium has been reached

     phiToroid(1:nthe, 1:npsi, 1:nzeta) = yy(1:nthe, 1:npsi, 1:nzeta)

     CALL Spline_coord_derivs(thetaVal, rhoVal, zetaVal, phiToroid, &
          & derivPhiTheta, derivPhiRho, derivPhiZeta)

     phij(1:nthe,1:npsi,1:nzeta) = xx(1:nthe,1:npsi,1:nzeta) * (jGradRho * derivPhiRho + &
          & jGradZeta * derivPhiZeta + jGradTheta * derivPhiTheta)

     ! Now compute TOTAL cross-tail current in the midnight meridional plane, and the "DST" (deflection due
     ! do jphi at the center of the Earth)

     totalCROSS = 0._dp
     dstBiot = 0._dp
     dstBiotInsideGeo = 0._dp
     
     DO i = 2, nthe-1
        DO j = 2, npsi
           totalCROSS = totalCROSS + jacobian(i,j,nZetaMidnight) * dr * dt * &
                ABS(SQRT(gradZetaSq(i,j,nZetaMidnight))) * phij(i,j,nZetaMidnight)
           DO k = 2, nzeta
              dstBiot = dstBiot + 1.E-7_dp * jacobian(i,j,k)*phij(i,j,k)*pjconst*1.E3_dp / &
                   (x(i,j,k)**2+y(i,j,k)**2+z(i,j,k)**2) * dr * dt * dpPrime * 6.4E6_dp * &
                   SQRT(x(i,j,k)**2+y(i,j,k)**2)/SQRT(x(i,j,k)**2+y(i,j,k)**2+z(i,j,k)**2)
              IF (xx(i,j,k) < 6.6_dp) dstBiotInsideGeo = dstBiotInsideGeo + 1.E-7_dp * &
                   jacobian(i,j,k)*phij(i,j,k)*pjconst*1E3 / &
                   (x(i,j,k)**2+y(i,j,k)**2+z(i,j,k)**2) * dr * dt * dpPrime * 6.4E6_DP * &
                   SQRT(x(i,j,k)**2+y(i,j,k)**2)/SQRT(x(i,j,k)**2+y(i,j,k)**2+z(i,j,k)**2)
           END DO
        END DO
     END DO
     
     ! Multiply by 1.3 to take into account currents induced inside Earth
     dstBiot = 1.3 * dstBiot
     dstBiotInsideGeo = 1.3 * dstBiotInsideGeo
     

     DO i = 2, nthe
        DO j = 2, npsi-1
           totalCROSS = totalCROSS + jacobian(i,j,nZetaMidnight) * dr * dt * &
                ABS(SQRT(gradZetaSq(i,j,nZetaMidnight))) * phij(i,j,nZetaMidnight)
           DO k = 2, nzeta
              dstComputed = dstComputed + 1.E-7_dp * jacobian(i,j,k)*phij(i,j,k)*pjconst*1E3 / &
                   (x(i,j,k)**2+y(i,j,k)**2+z(i,j,k)**2) * dr * dt * dpPrime * 6.4E6_DP * &
                   SQRT(x(i,j,k)**2+y(i,j,k)**2)/SQRT(x(i,j,k)**2+y(i,j,k)**2+z(i,j,k)**2)
           END DO
        END DO
     END DO

     !  PRINT*, 'Computed Dst is ', dstComputed, ' nT'

     ! Express physical quantities (use normalization constants)
     pjconst = 1.E6  * 0.31E-4 / (xzero3 * 4. * pi * 1.e-7 * 6.4E6)

     bj = bj * pjconst
     jParDirect = jParDirect * pjconst
     phij = phij * pjconst

     region1FAC = region1FAC * pjconst * 6.371**2    ! in MA; 6.371**2 is R_E**2
     region2FAC = region2FAC * pjconst * 6.371**2    ! in MA
     totalCROSS = totalCROSS * pjconst * 6.371**2    ! in MA

     IF (iPressureChoice/=5 .AND. iteration/=1) THEN
        PRINT*, ' '
        WRITE(*, '(A, 2X, G9.2)') &
             'Total azimuthal J - midnight meridian (MA): ', REAL(totalCROSS,sp)
        PRINT*, 'Total region 1 current in MA: ', REAL(region1FAC,sp)
        PRINT*, 'Total region 2 current in MA: ', REAL(region2FAC,sp)
        PRINT*, ' '
     END IF

!     distanceAlongLine(:,:,:) = 0._dp

!     DO k = 1, nzeta
!        DO j = 1, npsi
!           DO i = 2, nThetaEquator
!              distanceAlongLine(i,j,k) = distanceAlongLine(i-1,j,k) + &
!                   jacobian(nThetaEquator-i+2,j,k) / (f(j)*fzet(k)) * dt
!           END DO
!        END DO
!     END DO


     GOTO 101 ! Skip below for speed
     CALL cdf_open(ncdfId, 'jpar_study.cdf', 'w')

     dimlens(1) = nThetaEquator
     dimlens(2) = npsi
     dimlens(3) = nzeta
!     CALL cdf_define(ncdfId, 'distanceAlongLine', dimlens, 'R8') 

     dimlens(1) = nthe
     CALL cdf_define(ncdfId, 'xFull', dimlens, 'R8')
     CALL cdf_define(ncdfId, 'yFull', dimlens, 'R8')
     CALL cdf_define(ncdfId, 'zFull', dimlens, 'R8')
     CALL cdf_define(ncdfId, 'jCrossFull', dimlens, 'R8')
     CALL cdf_define(ncdfId, 'jParFullDirectOverB', dimlens, 'R8')
     CALL cdf_define(ncdfId, 'jParFull', dimlens, 'R8')
     CALL cdf_define(ncdfId, 'jParFullOverB', dimlens, 'R8')
     CALL cdf_define(ncdfId, 'generateFAC', dimlens, 'R8')
     CALL cdf_define(ncdfId, 'generateFACPAlpha', dimlens, 'R8')
     CALL cdf_define(ncdfId, 'generateFACPPsi', dimlens, 'R8')

     CALL cdf_write(ncdfId, 'xFull', x(1:nthe,1:npsi,1:nzeta))
     CALL cdf_write(ncdfId, 'yFull', y(1:nthe,1:npsi,1:nzeta))
     CALL cdf_write(ncdfId, 'zFull', z(1:nthe,1:npsi,1:nzeta))
     CALL cdf_write(ncdfId, 'jCrossFull', phij(1:nthe, 1:npsi, 1:nzeta))
     CALL cdf_write(ncdfId, 'jParFullDirectOverB', jParDirect(1:nthe,1:npsi,1:nzeta) / bf(1:nthe,1:npsi,1:nzeta))
     CALL cdf_write(ncdfId, 'jParFull', bj(1:nthe,1:npsi,1:nzeta))
     CALL cdf_write(ncdfId, 'jParFullOverB', bj(1:nthe,1:npsi,1:nzeta) / bf(1:nthe,1:npsi,1:nzeta))
!     CALL cdf_write(ncdfId, 'distanceAlongLine', distanceAlongLine(1:nThetaEquator,1:npsi,1:nzeta))
     CALL cdf_write(ncdfId, 'generateFAC', generateFAC(1:nthe,1:npsi,1:nzeta))
     CALL cdf_write(ncdfId, 'generateFACPAlpha', generateFACPAlpha(1:nthe,1:npsi,1:nzeta))
     CALL cdf_write(ncdfId, 'generateFACPPsi', generateFACPPsi(1:nthe,1:npsi,1:nzeta))
     CALL cdf_close(ncdfId)

101  CONTINUE


     RETURN

   END SUBROUTINE metrics
