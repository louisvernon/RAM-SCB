SUBROUTINE metrica(vecd,vec1,vec2,vec3,vec4,vec6,vec7,vec8,vec9)

  USE nrtype
  USE Module1

  IMPLICIT NONE

  REAL(DP), DIMENSION(:, :, :), INTENT(OUT) :: vecd, vec1, vec2, vec3, &
       vec4, vec6, vec7, vec8, vec9
  REAL(DP), DIMENSION(nthe) :: xa, xb, xc, xd, xe, xta, xtb, xtc, xtd, xte, &
       xpa, xpb, xpc, xpd, xpe, xra, xrb, xrc, xrd, xre, yta, ytb, ytc, ytd, yte, &
       ypa, ypb, ypc, ypd, ype, yra, yrb, yrc, yrd, yre, zta, ztb, ztc, ztd, zte, &
       zpa, zpb, zpc, zpd, zpe, zra, zrb, zrc, zrd, zre, &
       aja, ajb, ajc, ajd, aje, grxa, grya, grza, grxb, gryb, grzb, grxc, gryc, grzc, &
       grxd, gryd, grzd, grxe, grye, grze, gpxa, gpya, gpza, gpxb, gpyb, gpzb, gpxc, gpyc, gpzc, &
       gpxd, gpyd, gpzd, gpxe, gpye, gpze, gtxa, gtya, gtza, gtxb, gtyb, gtzb, gtxc, gtyc, gtzc, &
       gtxd, gtyd, gtzd, gtxe, gtye, gtze, grsa, grsb, grsc, grsd, grse, gpsa, gpsb, gpsc, gpsd, gpse, &
       gtsa, gtsb, gtsc, gtsd, gtse, grgpa, grgpb, grgpc, grgpd, grgpe, gpgta, gpgtb, gpgtc, gpgtd, &
       gpgte, gtgra, gtgrb, gtgrc, gtgrd, gtgre, v1a, v1b, v1c, v2a, v2b, v2c, v2d, v3a, v3b, v3c, &
       v3d, bsqa, bsqb, bsqc, bsqd

  INTEGER :: i, j, k, ierr

  DO  j=2,npsim
     DO  k=2,nzeta
        DO  i=2,nthem
           xa(i) = .5*(x(i,j,k)+x(i+1,j,k))
           xb(i) = .5*(x(i,j,k)+x(i,j,k+1))
           xc(i) = .5*(x(i,j,k)+x(i-1,j,k))
           xd(i) = .5*(x(i,j,k)+x(i,j,k-1))
           xe(i) = x(i,j,k)

           xta(i)=(x(i+1,j,k)-x(i,j,k))*rdt
           xtb(i)=(x(i+1,j,k+1)+x(i+1,j,k)-x(i-1,j,k+1)-x(i-1,j,k))*rdt4
           xtc(i)=(x(i,j,k)-x(i-1,j,k))*rdt
           xtd(i)=(x(i+1,j,k)+x(i+1,j,k-1)-x(i-1,j,k)-x(i-1,j,k-1))*rdt4
           xte(i)=(x(i+1,j,k)-x(i-1,j,k))*rdt2
           xpa(i)=(x(i+1,j,k+1)+x(i,j,k+1)-x(i+1,j,k-1)-x(i,j,k-1))*rdp4
           xpb(i)=(x(i,j,k+1)-x(i,j,k))*rdp
           xpc(i)=(x(i,j,k+1)+x(i-1,j,k+1)-x(i,j,k-1)-x(i-1,j,k-1))*rdp4
           xpd(i)=(x(i,j,k)-x(i,j,k-1))*rdp
           xpe(i)=(x(i,j,k+1)-x(i,j,k-1))*rdp2
           xra(i)=(x(i+1,j+1,k)+x(i,j+1,k)-x(i+1,j-1,k)-x(i,j-1,k))*rdr4
           xrb(i)=(x(i,j+1,k+1)+x(i,j+1,k)-x(i,j-1,k+1)-x(i,j-1,k))*rdr4
           xrc(i)=(x(i,j+1,k)+x(i-1,j+1,k)-x(i,j-1,k)-x(i-1,j-1,k))*rdr4
           xrd(i)=(x(i,j+1,k-1)+x(i,j+1,k)-x(i,j-1,k-1)-x(i,j-1,k))*rdr4
           xre(i)=(x(i,j+1,k)-x(i,j-1,k))*rdr2

           yta(i)=(y(i+1,j,k)-y(i,j,k))*rdt
           ytb(i)=(y(i+1,j,k+1)+y(i+1,j,k)-y(i-1,j,k+1)-y(i-1,j,k))*rdt4
           ytc(i)=(y(i,j,k)-y(i-1,j,k))*rdt
           ytd(i)=(y(i+1,j,k)+y(i+1,j,k-1)-y(i-1,j,k)-y(i-1,j,k-1))*rdt4
           yte(i)=(y(i+1,j,k)-y(i-1,j,k))*rdt2
           ypa(i)=(y(i+1,j,k+1)+y(i,j,k+1)-y(i+1,j,k-1)-y(i,j,k-1))*rdp4
           ypb(i)=(y(i,j,k+1)-y(i,j,k))*rdp
           ypc(i)=(y(i,j,k+1)+y(i-1,j,k+1)-y(i,j,k-1)-y(i-1,j,k-1))*rdp4
           ypd(i)=(y(i,j,k)-y(i,j,k-1))*rdp
           ype(i)=(y(i,j,k+1)-y(i,j,k-1))*rdp2
           yra(i)=(y(i+1,j+1,k)+y(i,j+1,k)-y(i+1,j-1,k)-y(i,j-1,k))*rdr4
           yrb(i)=(y(i,j+1,k+1)+y(i,j+1,k)-y(i,j-1,k+1)-y(i,j-1,k))*rdr4
           yrc(i)=(y(i,j+1,k)+y(i-1,j+1,k)-y(i,j-1,k)-y(i-1,j-1,k))*rdr4
           yrd(i)=(y(i,j+1,k-1)+y(i,j+1,k)-y(i,j-1,k-1)-y(i,j-1,k))*rdr4
           yre(i)=(y(i,j+1,k)-y(i,j-1,k))*rdr2

           zta(i)=(z(i+1,j,k)-z(i,j,k))*rdt
           ztb(i)=(z(i+1,j,k+1)+z(i+1,j,k)-z(i-1,j,k+1)-z(i-1,j,k))*rdt4
           ztc(i)=(z(i,j,k)-z(i-1,j,k))*rdt
           ztd(i)=(z(i+1,j,k)+z(i+1,j,k-1)-z(i-1,j,k)-z(i-1,j,k-1))*rdt4
           zte(i)=(z(i+1,j,k)-z(i-1,j,k))*rdt2
           zpa(i)=(z(i+1,j,k+1)+z(i,j,k+1)-z(i+1,j,k-1)-z(i,j,k-1))*rdp4
           zpb(i)=(z(i,j,k+1)-z(i,j,k))*rdp
           zpc(i)=(z(i,j,k+1)+z(i-1,j,k+1)-z(i,j,k-1)-z(i-1,j,k-1))*rdp4
           zpd(i)=(z(i,j,k)-z(i,j,k-1))*rdp
           zpe(i)=(z(i,j,k+1)-z(i,j,k-1))*rdp2
           zra(i)=(z(i+1,j+1,k)+z(i,j+1,k)-z(i+1,j-1,k)-z(i,j-1,k))*rdr4
           zrb(i)=(z(i,j+1,k+1)+z(i,j+1,k)-z(i,j-1,k+1)-z(i,j-1,k))*rdr4
           zrc(i)=(z(i,j+1,k)+z(i-1,j+1,k)-z(i,j-1,k)-z(i-1,j-1,k))*rdr4
           zrd(i)=(z(i,j+1,k-1)+z(i,j+1,k)-z(i,j-1,k-1)-z(i,j-1,k))*rdr4
           zre(i)=(z(i,j+1,k)-z(i,j-1,k))*rdr2

           aja(i) = xra(i)*(ypa(i)*zta(i)-yta(i)*zpa(i))  &
                +xpa(i)*(yta(i)*zra(i)-yra(i)*zta(i))  &
                +xta(i)*(yra(i)*zpa(i)-ypa(i)*zra(i))
           ajb(i) = xrb(i)*(ypb(i)*ztb(i)-ytb(i)*zpb(i))  &
                +xpb(i)*(ytb(i)*zrb(i)-yrb(i)*ztb(i))  &
                +xtb(i)*(yrb(i)*zpb(i)-ypb(i)*zrb(i))
           ajc(i) = xrc(i)*(ypc(i)*ztc(i)-ytc(i)*zpc(i))  &
                +xpc(i)*(ytc(i)*zrc(i)-yrc(i)*ztc(i))  &
                +xtc(i)*(yrc(i)*zpc(i)-ypc(i)*zrc(i))
           ajd(i) = xrd(i)*(ypd(i)*ztd(i)-ytd(i)*zpd(i))  &
                +xpd(i)*(ytd(i)*zrd(i)-yrd(i)*ztd(i))  &
                +xtd(i)*(yrd(i)*zpd(i)-ypd(i)*zrd(i))
           aje(i) = xre(i)*(ype(i)*zte(i)-yte(i)*zpe(i))  &
                +xpe(i)*(yte(i)*zre(i)-yre(i)*zte(i))  &
                +xte(i)*(yre(i)*zpe(i)-ype(i)*zre(i))
           jacobian(i,j,k) = aje(i)

!           IF (jacobian(i,j,k) < 0._dp) THEN
!              PRINT*, 'metrica: J < 0; i, j, k = ', i, j, k
!           END IF

           grxa(i) = (ypa(i)*zta(i)-yta(i)*zpa(i))/aja(i)
           grya(i) = (zpa(i)*xta(i)-zta(i)*xpa(i))/aja(i)
           grza(i) = (xpa(i)*yta(i)-xta(i)*ypa(i))/aja(i)
           grxb(i) = (ypb(i)*ztb(i)-ytb(i)*zpb(i))/ajb(i)
           gryb(i) = (zpb(i)*xtb(i)-ztb(i)*xpb(i))/ajb(i)
           grzb(i) = (xpb(i)*ytb(i)-xtb(i)*ypb(i))/ajb(i)
           grxc(i) = (ypc(i)*ztc(i)-ytc(i)*zpc(i))/ajc(i)
           gryc(i) = (zpc(i)*xtc(i)-ztc(i)*xpc(i))/ajc(i)
           grzc(i) = (xpc(i)*ytc(i)-xtc(i)*ypc(i))/ajc(i)
           grxd(i) = (ypd(i)*ztd(i)-ytd(i)*zpd(i))/ajd(i)
           gryd(i) = (zpd(i)*xtd(i)-ztd(i)*xpd(i))/ajd(i)
           grzd(i) = (xpd(i)*ytd(i)-xtd(i)*ypd(i))/ajd(i)
           grxe(i) = (ype(i)*zte(i)-yte(i)*zpe(i))/aje(i)
           grye(i) = (zpe(i)*xte(i)-zte(i)*xpe(i))/aje(i)
           grze(i) = (xpe(i)*yte(i)-xte(i)*ype(i))/aje(i)


           gpxa(i) = (yta(i)*zra(i)-yra(i)*zta(i))/aja(i)
           gpya(i) = (zta(i)*xra(i)-zra(i)*xta(i))/aja(i)
           gpza(i) = (xta(i)*yra(i)-xra(i)*yta(i))/aja(i)
           gpxb(i) = (ytb(i)*zrb(i)-yrb(i)*ztb(i))/ajb(i)
           gpyb(i) = (ztb(i)*xrb(i)-zrb(i)*xtb(i))/ajb(i)
           gpzb(i) = (xtb(i)*yrb(i)-xrb(i)*ytb(i))/ajb(i)
           gpxc(i) = (ytc(i)*zrc(i)-yrc(i)*ztc(i))/ajc(i)
           gpyc(i) = (ztc(i)*xrc(i)-zrc(i)*xtc(i))/ajc(i)
           gpzc(i) = (xtc(i)*yrc(i)-xrc(i)*ytc(i))/ajc(i)
           gpxd(i) = (ytd(i)*zrd(i)-yrd(i)*ztd(i))/ajd(i)
           gpyd(i) = (ztd(i)*xrd(i)-zrd(i)*xtd(i))/ajd(i)
           gpzd(i) = (xtd(i)*yrd(i)-xrd(i)*ytd(i))/ajd(i)
           gpxe(i) = (yte(i)*zre(i)-yre(i)*zte(i))/aje(i)
           gpye(i) = (zte(i)*xre(i)-zre(i)*xte(i))/aje(i)
           gpze(i) = (xte(i)*yre(i)-xre(i)*yte(i))/aje(i)

           gtxa(i) = (yra(i)*zpa(i)-ypa(i)*zra(i))/aja(i)
           gtya(i) = (zra(i)*xpa(i)-zpa(i)*xra(i))/aja(i)
           gtza(i) = (xra(i)*ypa(i)-xpa(i)*yra(i))/aja(i)
           gtxb(i) = (yrb(i)*zpb(i)-ypb(i)*zrb(i))/ajb(i)
           gtyb(i) = (zrb(i)*xpb(i)-zpb(i)*xrb(i))/ajb(i)
           gtzb(i) = (xrb(i)*ypb(i)-xpb(i)*yrb(i))/ajb(i)
           gtxc(i) = (yrc(i)*zpc(i)-ypc(i)*zrc(i))/ajc(i)
           gtyc(i) = (zrc(i)*xpc(i)-zpc(i)*xrc(i))/ajc(i)
           gtzc(i) = (xrc(i)*ypc(i)-xpc(i)*yrc(i))/ajc(i)
           gtxd(i) = (yrd(i)*zpd(i)-ypd(i)*zrd(i))/ajd(i)
           gtyd(i) = (zrd(i)*xpd(i)-zpd(i)*xrd(i))/ajd(i)
           gtzd(i) = (xrd(i)*ypd(i)-xpd(i)*yrd(i))/ajd(i)
           gtxe(i) = (yre(i)*zpe(i)-ype(i)*zre(i))/aje(i)
           gtye(i) = (zre(i)*xpe(i)-zpe(i)*xre(i))/aje(i)
           gtze(i) = (xre(i)*ype(i)-xpe(i)*yre(i))/aje(i)


           grsa(i) = ( grxa(i)**2+grya(i)**2+grza(i)**2 )
           grsb(i) = ( grxb(i)**2+gryb(i)**2+grzb(i)**2 )
           grsc(i) = ( grxc(i)**2+gryc(i)**2+grzc(i)**2 )
           grsd(i) = ( grxd(i)**2+gryd(i)**2+grzd(i)**2 )
           grse(i) = ( grxe(i)**2+grye(i)**2+grze(i)**2 )
           gpsa(i) = ( gpxa(i)**2+gpya(i)**2+gpza(i)**2 )
           gpsb(i) = ( gpxb(i)**2+gpyb(i)**2+gpzb(i)**2 )
           gpsc(i) = ( gpxc(i)**2+gpyc(i)**2+gpzc(i)**2 )
           gpsd(i) = ( gpxd(i)**2+gpyd(i)**2+gpzd(i)**2 )
           gpse(i) = ( gpxe(i)**2+gpye(i)**2+gpze(i)**2 )
           gtsa(i) = ( gtxa(i)**2+gtya(i)**2+gtza(i)**2 )
           gtsb(i) = ( gtxb(i)**2+gtyb(i)**2+gtzb(i)**2 )
           gtsc(i) = ( gtxc(i)**2+gtyc(i)**2+gtzc(i)**2 )
           gtsd(i) = ( gtxd(i)**2+gtyd(i)**2+gtzd(i)**2 )
           gtse(i) = ( gtxe(i)**2+gtye(i)**2+gtze(i)**2 )

           grgpa(i) = (gpxa(i)*grxa(i)+gpya(i)*grya(i)+gpza(i)*grza(i))
           grgpb(i) = (gpxb(i)*grxb(i)+gpyb(i)*gryb(i)+gpzb(i)*grzb(i))
           grgpc(i) = (gpxc(i)*grxc(i)+gpyc(i)*gryc(i)+gpzc(i)*grzc(i))
           grgpd(i) = (gpxd(i)*grxd(i)+gpyd(i)*gryd(i)+gpzd(i)*grzd(i))
           grgpe(i) = (gpxe(i)*grxe(i)+gpye(i)*grye(i)+gpze(i)*grze(i))

           gpgta(i) = (gpxa(i)*gtxa(i)+gpya(i)*gtya(i)+gpza(i)*gtza(i))
           gpgtb(i) = (gpxb(i)*gtxb(i)+gpyb(i)*gtyb(i)+gpzb(i)*gtzb(i))
           gpgtc(i) = (gpxc(i)*gtxc(i)+gpyc(i)*gtyc(i)+gpzc(i)*gtzc(i))
           gpgtd(i) = (gpxd(i)*gtxd(i)+gpyd(i)*gtyd(i)+gpzd(i)*gtzd(i))
           gpgte(i) = (gpxe(i)*gtxe(i)+gpye(i)*gtye(i)+gpze(i)*gtze(i))

           gtgra(i) = (gtxa(i)*grxa(i)+gtya(i)*grya(i)+gtza(i)*grza(i))
           gtgrb(i) = (gtxb(i)*grxb(i)+gtyb(i)*gryb(i)+gtzb(i)*grzb(i))
           gtgrc(i) = (gtxc(i)*grxc(i)+gtyc(i)*gryc(i)+gtzc(i)*grzc(i))
           gtgrd(i) = (gtxd(i)*grxd(i)+gtyd(i)*gryd(i)+gtzd(i)*grzd(i))
           gtgre(i) = (gtxe(i)*grxe(i)+gtye(i)*grye(i)+gtze(i)*grze(i))

           v1a(i)=(grsa(i)*gtsa(i)-gtgra(i)**2)*aja(i)*rdtsq
           v1b(i)=(grsb(i)*gtsb(i)-gtgrb(i)**2)*ajb(i)*rdtsq
           v1c(i)=(grsc(i)*gtsc(i)-gtgrc(i)**2)*ajc(i)*rdtsq
           v2a(i)=(grsa(i)*gpgta(i)-grgpa(i)*gtgra(i))*aja(i)*rdpdt4
           v2b(i)=(grsb(i)*gpgtb(i)-grgpb(i)*gtgrb(i))*ajb(i)*rdpdt4
           v2c(i)=(grsc(i)*gpgtc(i)-grgpc(i)*gtgrc(i))*ajc(i)*rdpdt4
           v2d(i)=(grsd(i)*gpgtd(i)-grgpd(i)*gtgrd(i))*ajd(i)*rdpdt4
           v3b(i)=(grsb(i)*gpsb(i)-grgpb(i)**2)*ajb(i)*rdpsq
           v3c(i)=(grsc(i)*gpsc(i)-grgpc(i)**2)*ajc(i)*rdpsq
           v3d(i)=(grsd(i)*gpsd(i)-grgpd(i)**2)*ajd(i)*rdpsq
           vecd(i,j,k) = (v1a(i)+v1c(i)) + (v3b(i)+v3d(i))
           vec1(i,j,k) = (v2c(i)+v2d(i))
           vec2(i,j,k) = (v2c(i)-v2a(i)) + v3d(i)
           vec3(i,j,k) = -(v2a(i)+v2d(i))
           vec4(i,j,k) = v1c(i) + (v2d(i)-v2b(i))
           vec6(i,j,k) = v1a(i) + (v2b(i)-v2d(i))
           vec7(i,j,k) = -(v2c(i)+v2b(i))
           vec8(i,j,k) = v3b(i) + (v2a(i)-v2c(i))
           vec9(i,j,k) = (v2a(i) + v2b(i))

           bsqa(i)=(grsa(i)*gpsa(i)-grgpa(i)**2)*(f(j)*fzet(k))**2
           bsqb(i)=(grsb(i)*gpsb(i)-grgpb(i)**2)*(f(j)*fzet(k))**2
           bsqc(i)=(grsc(i)*gpsc(i)-grgpc(i)**2)*(f(j)*fzet(k))**2
           bsqd(i)=(grsd(i)*gpsd(i)-grgpd(i)**2)*(f(j)*fzet(k))**2
           bsq(i,j,k)=(grse(i)*gpse(i)-grgpe(i)**2)*(f(j)*fzet(k))**2
           bf(i,j,k) = SQRT(bsq(i,j,k))
        END DO
     END DO
  END DO

  bf(:,:,1) = bf(:,:,nzeta)

  DO  k=1, nzetp
     DO  j=2,npsim
        CALL extap(bf(4,j,k),bf(3,j,k),bf(2,j,k),bf(1,j,k))
        CALL extap(bf(nthe-3,j,k),bf(nthe-2,j,k),bf(nthe-1,j,k) ,bf(nthe,j,k))
     END DO

     DO  i=1,nthe
        CALL extap(bf(i,4,k),bf(i,3,k),bf(i,2,k),bf(i,1,k))
        CALL extap(bf(i,npsi-3,k),bf(i,npsi-2,k),bf(i,npsi-1,k) ,bf(i,npsi,k))
     END DO

  END DO

  bsq = bf*bf

  RETURN

END SUBROUTINE metrica

