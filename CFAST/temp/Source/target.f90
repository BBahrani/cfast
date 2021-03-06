    
! --------------------------- trheat -------------------------------------------

    subroutine trheat(update,method,dt,xpsolve,delta)

    !     routine: trheat (main target routine)
    !     purpose: compute dassl residuals associated with targets
    !     arguments: update   variable indicating whether temperature profile should be updated
    !                method   one of steady, mplicit or xplicit (note: these are parameter values, not mis-pelld)
    !                dt       time step
    !                xpsolve  dassl derivative estimate
    !                delta    dassl residual array
    !     revision: $revision: 464 $
    !     revision date: $date: 2012-06-29 15:41:23 -0400 (fri, 29 jun 2012) $

    use precision_parameters
    use cenviro
    use cfast_main
    use fltarget
    implicit none
    
    integer, intent(in) :: update, method
    real(eb), intent(in) :: dt,  xpsolve(*)
    
    real(eb), intent(out) :: delta(*)

    logical :: first=.true.
    real(eb) :: tmp(trgtnum), walldx(trgtnum), tgrad(2), wk(1), wspec(1), wrho(1), tempin, tempout
    real(eb) :: tderv, ddtemp, ttold, ttnew, sum, wfluxin, wfluxout, xl
    integer :: nnn, i, itarg, nmnode(2), ieq, iieq, iwbound, nslab, iimeth
    save first,tmp

    if(method==steady)return

    ! initialize non-dimensional target node locations the first time trheat is called
    if(first)then
        first = .false.
        nnn = trgtnum - 1
        tmp(1) = 1.0_eb
        tmp(nnn) = 1.0_eb
        do i = 2, nnn/2 
            tmp(i) = tmp(i-1)*1.50_eb
            tmp(nnn+1-i) = tmp(i)
        end do
        if(mod(nnn,2)==1)tmp(nnn/2+1)=tmp(nnn/2)*1.50_eb
        sum = 0.0_eb
        do i = 1, nnn
            sum = sum + tmp(i)
        end do
        do i = 1, nnn
            tmp(i) = tmp(i)/sum
        end do
    endif

    ! calculate net flux striking each side of target
    call target(method)

    ! for each target calculate ode or pde residual and update target temperature (if update=1 or 1)
    do itarg = 1, ntarg
        if(ixtarg(trgmeth,itarg)==method) then
            wfluxin = xxtarg(trgnfluxf,itarg)
            wfluxout = xxtarg(trgnfluxb,itarg)
            wspec(1) = xxtarg(trgcp,itarg)
            wrho(1) =  xxtarg(trgrho,itarg)
            wk(1) =  xxtarg(trgk,itarg)
            xl = xxtarg(trgl,itarg)
            iimeth = ixtarg(trgmeth,itarg)
            iieq = ixtarg(trgeq,itarg)

            ! compute the pde residual 
            if(iieq==pde.or.iieq==cylpde)then
                if(iimeth==mplicit)then
                    tempin = xxtarg(trgtempf,itarg)
                    iwbound = 3
                else
                    iwbound = 4
                endif
                nmnode(1) = trgtnum
                nmnode(2) = trgtnum - 2
                nslab = 1
                if(iieq==pde)then
                    do i = 1, trgtnum - 1
                        walldx(i) = xl*tmp(i)
                    end do

                    call cnduct(update,tempin,tempout,dt,wk,wspec,wrho,xxtarg(trgtempf,itarg),walldx,nmnode,nslab,wfluxin,wfluxout,iwbound,tgrad,tderv)
                    if(iimeth==mplicit)then
                        ieq = iztarg(itarg)
                        delta(noftt+ieq) = xxtarg(trgnfluxf,itarg)+wk(1)*tgrad(1)
                    endif
                else if(iieq==cylpde)then
                    call cylcnduct(xxtarg(trgtempf,itarg),nmnode(1),(wfluxin+wfluxout),dt,wk(1),wrho(1),wspec(1),xl)          
                endif

                ! compute the ode residual
            elseif(iieq==ode)then
                ddtemp = (wfluxin+wfluxout)/(wspec(1)*wrho(1)*xl)
                if(iimeth==mplicit)then
                    ieq = iztarg(itarg)
                    delta(noftt+ieq) = ddtemp - xpsolve(noftt+ieq) 
                elseif(iimeth==xplicit)then
                    if(update/=0)then
                        ttold = xxtarg(trgtempf,itarg)
                        ttnew = ttold + dt*ddtemp
                        xxtarg(trgtempf,itarg) = ttnew
                    endif
                endif

                ! error, the equation type can has to be either pde or ode if the method is not steady
            else

            endif
        end if
    end do
    return
    end subroutine trheat
    
! --------------------------- target -------------------------------------------

    subroutine target(method)

    !     routine: target
    !     purpose: routine to calculate total flux striking a target. this flux is used to calculate a target temperature,
    !              assuming that the sum of incoming and outgoing flux is zero, ie, assuming that the target is at steady state.
    !     arguments: method  

    use precision_parameters
    use cenviro
    use cfast_main
    use fltarget
    implicit none

    integer, intent(in) :: method
    
    real(eb) :: flux(2), dflux(2), ttarg(2), ddif
    integer :: itarg, methtarg, iroom, niter, iter

    ! calculate flux to user specified targets, assuming target is at thermal equilibrium
    if (ntarg>nm1) then
        do itarg = 1, ntarg
            methtarg = ixtarg(trgmeth,itarg)
            if(method==methtarg) then
                iroom = ixtarg(trgroom,itarg)
                if(methtarg==steady)then
                    niter = 10
                else
                    niter = 1
                endif
                ttarg(1) = xxtarg(trgtempf,itarg)
                ttarg(2) = xxtarg(trgtempb,itarg)
                do iter = 1, niter
                    call targflux(iter,itarg,ttarg,flux,dflux)
                    if(dflux(1)/=0.0_eb.and.methtarg==steady)then
                        ddif = flux(1)/dflux(1)
                        ttarg(1) = ttarg(1) - ddif
                        if(abs(ddif)<=1.0d-5*ttarg(1)) exit
                    endif
                end do
                if(methtarg==steady)then
                    xxtarg(trgtempf,itarg) = ttarg(1)
                    xxtarg(trgtempb,itarg) = ttarg(2)
                endif
                xxtarg(trgtfluxf,itarg) = qtwflux(itarg,1) + qtfflux(itarg,1) + qtcflux(itarg,1) + qtgflux(itarg,1)
                xxtarg(trgtfluxb,itarg) = qtwflux(itarg,2) + qtfflux(itarg,2) + qtcflux(itarg,2) + qtgflux(itarg,2)
                call targflux(niter+1,itarg,ttarg,flux,dflux)
                xxtarg(trgnfluxf,itarg) = flux(1)
                xxtarg(trgnfluxb,itarg) = flux(2)
            end if
        end do
    endif

    ! calculate flux to floor targets for the pre-existing data structure, ontarget, and a flashover indicator on the floor
    if(method==steady)then
        do iroom = 1, nm1
            itarg = ntarg - nm1 + iroom

            ! ambient target
            ttarg(1) = tamb(iroom)
            ttarg(2) = eta(iroom)
            xxtarg(trgtempf,itarg) = ttarg(1)
            call targflux(1,itarg,ttarg,flux,dflux)
            xxtarg(trgtfluxf,itarg) = qtwflux(itarg,1) + qtfflux(itarg,1) + qtcflux(itarg,1) + qtgflux(itarg,1)
            ontarget(iroom) = xxtarg(trgtfluxf,itarg)-sigma*ttarg(1)**4

            ! flashover indicator
            ttarg(1) = zzwtemp(iroom,2,1)
            xxtarg(trgtempf,itarg) = ttarg(1)
            call targflux(1,itarg,ttarg,flux,dflux)
            xxtarg(trgtfluxf,itarg) = qtwflux(itarg,1) + qtfflux(itarg,1) + qtcflux(itarg,1) + qtgflux(itarg,1)
            xxtarg(trgnfluxf,itarg) = qtwflux(itarg,1) + qtfflux(itarg,1) + qtcflux(itarg,1) + qtgflux(itarg,1) - sigma*ttarg(1)**4
        end do
    endif

    return
    end subroutine target
    
! --------------------------- targflux -------------------------------------------

    subroutine targflux(iter,itarg,ttarg,flux,dflux)

    !     routine: target
    !     purpose: routine to calculate flux (and later, temperature) of a target.
    !     arguments: iter   iteration number
    !                itarg  targetnumber
    !                ttarg  front and back target input temperature
    !                flux   front and back output flux
    !                dflux  front and back output flux derivative

    use precision_parameters
    use cenviro
    use cfast_main
    use fltarget
    use objects2
    use wnodes
    implicit none

    integer, intent(in) :: iter, itarg
    real(eb), intent(in) :: ttarg(2)

    real(eb) :: flux(2), dflux(2)
    
    real(eb) :: svect(3), qwtsum(2), awallsum(2), qgassum(2), absu, absl, cosang, cosangt, s, dnrm2, ddot, zfire, &
        xtarg, ytarg, ztarg, zlay, zl, zu, taul, tauu, qfire, absorb, qft, qout, zwall, tl, tu, alphal, alphau, awall, qwt, qgas, qgt, zznorm, tg, tgb, &
        ttargb, dttarg, dttargb, temis, q1, q2, q1b, q2b, q1g, dqdtarg, dqdtargb, total_radiation, re_radiation
    integer :: map10(10), iroom, i, nfirerm, istart, ifire, iwall, jj, iw, iwb, irtarg
    
    type(room_type), pointer :: roomi

    data map10/1,3,3,3,3,4,4,4,4,2/

    absu = 0.50_eb
    absl = 0.01_eb
    iroom = ixtarg(trgroom,itarg)
    roomi=>roominfo(iroom)
    
    ! terms that do not depend upon the target temperature only need to be calculated once
    if(iter==1)then

        ! initialize flux counters: total, fire, wall, gas 
        do i = 1, 2
            qtfflux(itarg,i) = 0.0_eb
            qtgflux(itarg,i) = 0.0_eb
            qtwflux(itarg,i) = 0.0_eb
        end do

        nfirerm = ifrpnt(iroom,1)
        istart = ifrpnt(iroom,2)

        ! compute radiative flux from fire
        do ifire = istart, istart + nfirerm - 1
            svect(1) = xxtarg(trgcenx,itarg) - xfire(ifire,1)
            svect(2) = xxtarg(trgceny,itarg) - xfire(ifire,2)
            svect(3) = xxtarg(trgcenz,itarg) - xfire(ifire,3)
            cosang = 0.0_eb
            s = max(dnrm2(3,svect,1),objclen(ifire))
            if(s/=0.0_eb)then
                cosang = -ddot(3,svect,1,xxtarg(trgnormx,itarg),1)/s
            endif
            zfire = xfire(ifire,3)
            ztarg = xxtarg(trgcenz,itarg)
            zlay = zzhlay(iroom,lower)

            ! compute portion of path in lower and upper layers
            call getylyu(zfire,zlay,ztarg,s,zl,zu)
            if(nfurn>0)then
                absl=0.0
                absu=0.0
                taul = 1.0_eb
                tauu = 1.0_eb
                qfire = 0.0_eb
            else
                absl = absorb(iroom, lower)
                absu = absorb(iroom, upper)
                taul = exp(-absl*zl)
                tauu = exp(-absu*zu)
                qfire = xfire(ifire,8)
            endif
            if(s/=0.0_eb)then
                qft = qfire*abs(cosang)*tauu*taul/(4.0_eb*pi*s**2)
            else
                qft = 0.0_eb
            endif

            ! decide whether flux is hitting front or back of target. if it's hitting the back target only add contribution if the target is interior to the room
            if(cosang>=0.0_eb)then
                qtfflux(itarg,1) = qtfflux(itarg,1) + qft
            else
                if(ixtarg(trgback,itarg)==int)then
                    qtfflux(itarg,2) = qtfflux(itarg,2) + qft
                endif
            endif

        end do

        ! compute radiative flux from walls and gas

        do i = 1, 2
            awallsum(i) = 0.0_eb   
            qwtsum(i) = 0.0_eb
            qgassum(i) = 0.0_eb
        end do
        do iwall = 1, 10
            if(nfurn>0)then
                qout=qfurnout
            else
                qout = rdqout(map10(iwall),iroom)
            endif
            svect(1) = xxtarg(trgcenx,itarg) - roomi%wall_center(iwall,1)
            svect(2) = xxtarg(trgceny,itarg) - roomi%wall_center(iwall,2)
            svect(3) = xxtarg(trgcenz,itarg) - roomi%wall_center(iwall,3)
            cosangt = 0.0_eb
            s = dnrm2(3,svect,1)
            if(s/=0.0_eb)then
                cosangt = -ddot(3,svect,1,xxtarg(trgnormx,itarg),1)/s
            endif
            zwall = roomi%wall_center(iwall,3)
            ztarg = xxtarg(trgcenz,itarg)
            zlay = zzhlay(iroom,lower)
            tl = zztemp(iroom,lower)
            tu = zztemp(iroom,upper)

            ! compute path length in lower (zl) and upper (zu) layer
            call getylyu(zwall,zlay,ztarg,s,zl,zu)

            ! find fractions transmitted and absorbed in lower and upper layer
            taul = exp(-absl*zl)
            alphal = 1.0_eb - taul
            tauu = exp(-absu*zu)
            alphau = 1.0_eb - tauu

            awall = zzwarea2(iroom,iwall)
            qwt = qout*taul*tauu
            if(iwall<=5)then
                qgas = tl**4*alphal*tauu + tu**4*alphau
            else
                qgas = tu**4*alphau*taul + tl**4*alphal
            endif
            qgt = sigma*qgas
            if(cosangt>=0.0_eb)then
                jj = 1
            else 
                jj = 2
            endif

            ! calculate flux on the target front.  calculate flux on the target back only if the rear of the target is interior to the room.
            if(jj==1.or.ixtarg(trgback,itarg)==int)then
                qwtsum(jj) = qwtsum(jj) + qwt*awall
                qgassum(jj) = qgassum(jj) + qgt*awall
                awallsum(jj) = awallsum(jj) + awall
            endif
        end do
        do i = 1, 2
            if(awallsum(i)==0.0_eb)awallsum(i) = 1.0_eb
            qtwflux(itarg,i) = qwtsum(i)/awallsum(i)
            qtgflux(itarg,i) = qgassum(i)/awallsum(i)
        end do       

        ! if the target rear was exterior then calculate the flux assuming ambient outside conditions
        if(ixtarg(trgback,itarg)==ext.or.qtgflux(itarg,2)==0.0)then
            qtgflux(itarg,2) = sigma*tamb(iroom)**4
        endif
    endif

    ! compute convective flux
    ! assume target is a 'floor', 'ceiling' or 'wall' depending on how much the target is tilted.  
    zznorm = xxtarg(trgnormz,itarg)
    if(zznorm<=1.0_eb.and.zznorm>=cos45)then
        iw = 2
        iwb = 1
    elseif(zznorm>=-1.0_eb.and.zznorm<=-cos45)then
        iw = 1
        iwb = 2
    else
        iw = 3
        iwb = 3
    endif
    irtarg = ixtarg(trgroom,itarg)
    xtarg = xxtarg(trgcenx,itarg)
    ytarg = xxtarg(trgceny,itarg)
    ztarg = xxtarg(trgcenz,itarg)
    call gettgas(irtarg,xtarg,ytarg,ztarg,tg)
    tgtarg(itarg) = tg
    if(ixtarg(trgback,itarg)==int)then
        tgb = tg
    else
        tgb = tamb(iroom)
    endif
    ttargb = ttarg(2)
    dttarg = 1.0d-7*ttarg(1)
    dttargb = 1.0d-7*ttarg(2)

    temis = xxtarg(trgemis,itarg)

    ! convection for the front
    call convec(iw,tg,ttarg(1),q1)
    call convec(iw,tg,ttarg(1)+dttarg,q2)
    qtcflux(itarg,1) = q1
    dqdtarg = (q2-q1)/dttarg

    flux(1) = temis*(qtfflux(itarg,1) + qtwflux(itarg,1) + qtgflux(itarg,1)) + qtcflux(itarg,1) - temis*sigma*ttarg(1)**4
    dflux(1) = -4.0_eb*temis*sigma*ttarg(1)**3 + dqdtarg

    ! this is for "gauge" heat flux output ... it assumes an ambient temperature target
    gtflux(itarg,2) = qtfflux(itarg,1)
    gtflux(itarg,3) = qtwflux(itarg,1)
    gtflux(itarg,4) = qtgflux(itarg,1)
    
    ! Adjust each one for the ambient losses
    total_radiation = gtflux(itarg,2) + gtflux(itarg,3) + gtflux(itarg,4)
    re_radiation = sigma*tamb(iroom)**4
    gtflux(itarg,2) = gtflux(itarg,2) - re_radiation*gtflux(itarg,2)/total_radiation
    gtflux(itarg,3) = gtflux(itarg,3) - re_radiation*gtflux(itarg,3)/total_radiation
    gtflux(itarg,4) = gtflux(itarg,4) - re_radiation*gtflux(itarg,4)/total_radiation
    
    !add in the convection 
    call convec(iw,tg,tamb(iroom),q1g)
    gtflux(itarg,5) = q1g
    
    ! and the total is just the sum of these
    gtflux(itarg,1) = gtflux(itarg,2) + gtflux(itarg,3) + gtflux(itarg,4) + gtflux(itarg,5)


    ! convection for the back
    call convec(iwb,tgb,ttargb,q1b)
    call convec(iwb,tgb,ttargb+dttargb,q2b)
    qtcflux(itarg,2) = q1b
    dqdtargb = (q2b-q1b)/dttargb

    flux(2) = temis*(qtfflux(itarg,2) + qtwflux(itarg,2) + qtgflux(itarg,2)) + qtcflux(itarg,2) - temis*sigma*ttargb**4
    dflux(2) = -4.0_eb*temis*sigma*ttargb**3 + dqdtargb

    return
    end subroutine targflux
    
! --------------------------- gettgas -------------------------------------------

    subroutine gettgas(irtarg,xtarg,ytarg,ztarg,tg)

    !     routine: gettgas
    !     purpose: routine to calculate gas temperature nearby a target
    !     arguments: irtarg target number
    !                xtarg  x position of target in compartmentnumber
    !                ytarg  y position of target in compartmentnumber
    !                ztarg  z position of target in compartment
    !                tgas (output)   calculated gas temperature

    use precision_parameters
    use cfast_main
    use cenviro
    use objects2
    implicit none

    integer, intent(in) :: irtarg
    real(eb), intent(in) :: xtarg, ytarg, ztarg
    
    real(eb), intent(out) :: tg
        
    real(eb) :: qdot, xrad, dfire, tu, tl, zfire, zlayer, z, tplume

    integer :: i

    ! default is the appropriate layer temperature
    if (ztarg>=zzhlay(irtarg,lower)) then
        tg = zztemp(irtarg,upper)
    else
        tg = zztemp(irtarg,lower)
    endif

    ! if there is a fire in the room and the target is DIRECTLY above the fire, use plume temperature
    do i = 1,nfire
        if (ifroom(i)==irtarg) then
            if (xtarg==xfire(i,1).and.ytarg==xfire(i,2).and. ztarg>xfire(i,3)) then
                qdot = fqf(i)
                xrad = radconsplit(i)
                dfire = 2.0_eb*sqrt(farea(i)/pi)
                tu = zztemp(irtarg,upper)
                tl = zztemp(irtarg,lower)
                zfire = xfire(i,3)
                zlayer = zzhlay(irtarg,lower)
                z = ztarg
                call plumetemp (qdot, xrad, tu, tl, zfire, zlayer, z, tplume)
                tg = tplume
            endif
        endif
    end do 
    end subroutine gettgas 
    
! --------------------------- getylyu -------------------------------------------

    subroutine getylyu(yo,y,yt,s,yl,yu)

    !     routine: gettylyu
    !     purpose: compute portion of path in lower and upper layers

    use precision_parameters
    implicit none
    
    real(eb), intent(in) :: yo, y, yt, s
    real(eb), intent(out) :: yl, yu


    if(yo<=y)then
        if(yt<=y)then
            yl = 1.0_eb
        else
            yl = (y-yo)/(yt-yo)
        endif
    else
        if(yt>=y)then
            yl = 0.0_eb
        else
            yl = (y-yt)/(yo-yt)
        endif
    endif
    yl = yl*s
    yu = s - yl
    return
    end subroutine getylyu
    
! --------------------------- updtect -------------------------------------------

    subroutine updtect(imode,tcur,dstep,ndtect,zzhlay,zztemp,xdtect,ixdtect,iquench,idset,ifdtect,tdtect)

    !     routine: gettylyu
    !     purpose: this routine updates the temperature of each detector link.  it also determine whether the detector has activated 
    !              in the time interval (tcur,tcur+dstep).  if this has occured then a quenching algorithm will be invoked if the appropriate option has been set.
    !     arguments: tcur    current time
    !                dstep   time step size (to next time)
    !                ndtect  number of detectors
    !                xdtect  2-d array containing floating point detector data structures 
    !                ixdtect 2-d array containing integer detector data structures
    !                iquench if the j=iquench(i) is non-zero then the j'th sprinkler in the i'th room is quenching the fire
    !                idset   room where activated detector resides

    use precision_parameters
    use cparams
    use dsize
    implicit none

    integer, intent(in) :: imode, ndtect
    real(eb), intent(in) :: tcur, dstep, zzhlay(nr,2), zztemp(nr,2)
    
    integer, intent(out) :: idset, ifdtect, ixdtect(mxdtect,*), iquench(*)
    real(eb), intent(out) :: xdtect(mxdtect,*), tdtect
    
    real(eb) :: cjetmin, tlink, tlinko, zdetect, tlay, tjet, tjeto, vel, velo, rti, trig, an, bn, anp1, bnp1, denom, fact1, fact2, delta, tmp
    integer :: i, iroom, idold, iqu

    idset = 0
    ifdtect = 0
    tdtect = tcur+2*dstep
    cjetmin = 0.10_eb
    do i = 1, ndtect
        iroom = ixdtect(i,droom)
        tlinko = xdtect(i,dtemp)

        zdetect = xdtect(i,dzloc)
        if(zdetect>zzhlay(iroom,lower))then
            tlay = zztemp(iroom,upper)
        else
            tlay = zztemp(iroom,lower)
        endif

        tjet = max(xdtect(i,dtjet),tlay)
        tjeto = max(xdtect(i,dtjeto),tlay)
        vel = max(xdtect(i,dvel),cjetmin)
        velo = max(xdtect(i,dvelo),cjetmin)

        rti = xdtect(i,drti)
        trig = xdtect(i,dtrig)
        if(ixdtect(i,dtype)==smoked)then
            tlink = tjet
        elseif(ixdtect(i,dtype)==heatd)then
            bn = sqrt(velo)/rti
            an = bn*tjeto
            bnp1 = sqrt(vel)/rti
            anp1 = bnp1*tjet
            denom = 1.0_eb + dstep*bnp1*.5_eb
            fact1 = (1.0_eb - dstep*bn*.50_eb)/denom
            fact2 = dstep/denom
            tlink = fact1*tlinko + fact2*(an+anp1)*0.5_eb
        else

            ! when soot is calculated then set tlink to soot concentration. set it to zero for now.
            tlink = 0.0_eb
        endif
        if (imode>0) then
            xdtect(i,dtempo) = tlinko
            xdtect(i,dtemp) = tlink
        endif

        ! determine if detector has activated in this time interval (and not earlier)
        if(tlinko<trig.and.trig<=tlink.and.ixdtect(i,dact)==0)then
            delta = (trig-tlinko)/(tlink-tlinko)
            tmp = tcur+dstep*delta
            tdtect = min(tmp,tdtect)
            ifdtect = i
            if (imode>0) then
                xdtect(i,dtact)= tcur+dstep*delta
                ixdtect(i,dact) = 1

                ! determine if this is the first detector to have activated in this room
                idold = iquench(iroom)
                iqu = 0
                if(idold==0)then
                    iqu = i
                else
                    if(xdtect(i,dtact)<xdtect(idold,dtact))then

                        ! this can only happen if two detectors have activated in the same room in the same (possibly very short) time interval
                        iqu = i
                    endif
                endif

                ! if this detector has activated before all others in this room and the quenching flag was turned on then let the sprinkler quench the fire
                if(iqu/=0.and.ixdtect(i,dquench)==1)then
                    iquench(iroom)=iqu
                    idset = iroom
                endif
            endif
        endif
        xdtect(i,dtjeto) = tjet
        xdtect(i,dvelo) = vel
    end do
    return
    end subroutine updtect
    
! --------------------------- rev_target -------------------------------------------

    integer function rev_target ()

    integer :: module_rev
    character(255) :: module_date 
    character(255), parameter :: mainrev='$Revision$'
    character(255), parameter :: maindate='$Date$'

    write(module_date,'(a)') mainrev(index(mainrev,':')+1:len_trim(mainrev)-2)
    read (module_date,'(i5)') module_rev
    rev_target = module_rev
    write(module_date,'(a)') maindate
    return
    end function rev_target