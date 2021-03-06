FUNCTION SavGol7(pres)
  ! Savitzky-Golay smoothing (1-D passes in both directions) using quadratic polynomial and 7 pts

  USE nrtype, ONLY : DP

  IMPLICIT NONE

  REAL(DP), INTENT(IN) :: pres(:,:)
  REAL(DP), DIMENSION(SIZE(pres,1),SIZE(pres,2)) :: SavGol7, pres0, pres1, pres2
  REAL(DP) :: BSav(7,7)

  INTEGER :: ier, iPass, j, k, nrad, nphi

  nrad = SIZE(pres,1)
  nphi = SIZE(pres,2)

  pres0 = pres

DO iPass = 1, 3 ! Single or multiple pass

BSav = RESHAPE((/32, 5, 1, -2, -2, -1, 5, &
       15, 4, 3, 3, 1, 0, -3, &
       3, 3, 4, 6, 3, 1, -6, &
       -4, 2, 4, 7, 4, 2, -4, &
       -6, 1, 3, 6, 4, 3, 3, &
       -3, 0, 1, 3, 3, 4, 15, &
       5, -1, -2, -2, 1, 5, 32/), (/7,7/))
  ! Reshapes in Fortran normal order (storage by columns)

  ! First pass in the j direction
  DO k = 1, nphi
     DO j = 1, nrad
        IF (j > 3 .AND. j < nrad-2) THEN
           pres1(j,k) = DOT_PRODUCT(BSav(4,:)/21., pres0(j-3:j+3,k))
        ELSE IF (j == 1) THEN
           pres1(j,k) = DOT_PRODUCT(BSav(1,:)/42., pres0(1:7,k))
        ELSE IF (j == 2) THEN
           pres1(j,k) = DOT_PRODUCT(BSav(2,:)/14., pres0(1:7,k))
        ELSE IF (j == 3) THEN
           pres1(j,k) = DOT_PRODUCT(BSav(3,:)/14., pres0(1:7,k))
        ELSE IF (j == nrad-2) THEN
           pres1(j,k) = DOT_PRODUCT(BSav(5,:)/14., pres0(nrad-6:nrad,k))
        ELSE IF (j == nrad-1) THEN
           pres1(j,k) = DOT_PRODUCT(BSav(6,:)/14., pres0(nrad-6:nrad,k))
        ELSE IF (j == nrad) THEN
           pres1(j,k) = DOT_PRODUCT(BSav(7,:)/42., pres0(nrad-6:nrad,k))
        ELSE
           STOP 'SavGol7 problem.'
        END IF
     END DO
  END DO

  ! Here all are centered and there is a common weight of 21 (Table I of [Gorry, 1990])
  ! Second pass in the k (phi) direction
  BSav = Bsav/21.
  DO j = 1, nrad
     DO k = 1, nphi
        IF (k > 3 .AND. k < nphi-2) THEN
           pres2(j,k) = DOT_PRODUCT(BSav(4,:), pres1(j,k-3:k+3))
        ELSE IF (k == 1 .OR. k == nphi) THEN
           pres2(j,k) = DOT_PRODUCT(BSav(4,:), (/pres1(j,nphi-3),pres1(j,nphi-2), &
                pres1(j,nphi-1),pres1(j,1),pres1(j,2),pres1(j,3),pres1(j,4)/))
        ELSE IF (k == 2) THEN
           pres2(j,k) = DOT_PRODUCT(BSav(4,:), (/pres1(j,nphi-2),&
                pres1(j,nphi-1),pres1(j,1),pres1(j,2),pres1(j,3),pres1(j,4),pres1(j,5)/))
        ELSE IF (k == nphi-1) THEN
           pres2(j,k) = DOT_PRODUCT(BSav(4,:), (/pres1(j,nphi-4),pres1(j,nphi-3),&
                pres1(j,nphi-2),pres1(j,nphi-1),pres1(j,1),pres1(j,2),pres1(j,3)/))
        ELSE IF (k == 3) THEN
           pres2(j,k) = DOT_PRODUCT(BSav(4,:), (/pres1(j,nphi-1),&
                pres1(j,1),pres1(j,2),pres1(j,3),pres1(j,4),pres1(j,5),pres1(j,6)/))
        ELSE IF (k == nphi-2) THEN
           pres2(j,k) = DOT_PRODUCT(BSav(4,:), (/pres1(j,nphi-5),pres1(j,nphi-4),&
                pres1(j,nphi-3),pres1(j,nphi-2),pres1(j,nphi-1),pres1(j,1),pres1(j,2)/))
        ELSE
           STOP 'SavGol7 problem'
        END IF
     END DO
  END DO

pres0 = pres2

END DO

SavGol7 = pres2

  WHERE (SavGol7 < 0) SavGol7 = MINVAL(pres)

  RETURN

END FUNCTION SavGol7
