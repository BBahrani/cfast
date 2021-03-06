 module convection_routines
    
    use precision_parameters
    use fireptrs
    use wallptrs
    use cparams
    use cenviro
    use cfast_main
    use wnodes
    use opt
    
    implicit none
    
    private

   public convection, convective_flux

   contains
   
   subroutine convection (flwcv,flxcv)

    !     routine:    convection
    !     function:   interface between calculate_residuals and convective_flux.  loops over rooms
    !                 setting up varibles.  passes to convective_flux if ceiling jet for
    !                 a surface is off, otherwise sets flxcv to 0.0 and then
    !                 solves for flwcv
    !     outputs:    flwcv       net enthalphy into each layer 
    !                 flxcv       net heat flux onto surface


    real(eb), intent(out) :: flwcv(nr,2), flxcv(nr,nwal)
    
    real(eb) :: qconv, qconv_avg
    
    integer i, iwall, iw, nrmfire, ilay, ifire
    type(room_type), pointer :: roomptr


    flwcv(1:nm1,upper) = 0.0_eb
    flwcv(1:nm1,lower) = 0.0_eb
    flxcv(1:nm1,1:nwal) = 0.0_eb
            
    if (option(fconvec)/=on) return

    ! calculate convection for all surfaces in all rooms
    do iw = 1, nwalls
        i = izwall(iw,w_from_room)
        roomptr => roominfo(i)
        iwall = izwall(iw,w_from_wall)
        nrmfire = ifrpnt(i,1)
        if(mod(iwall,2)==1)then
            ilay = upper
        else
            ilay = lower
        endif
        ! assume no fires in this room.  just use regular convection
        call convective_flux(iwall,zztemp(i,ilay),zzwtemp(i,iwall,1),flxcv(i,iwall))
        ! if there's a fire, we may need to modify the convection to account for the ceiling jet
        if (iwall==1.and.nrmfire>0) then
            qconv = 0.0_eb
            do ifire = 1, nrmfire
                qconv = max(qconv,xfire(ifrpnt(i,2)+ifire-1,f_qfc))
            end do
            qconv_avg = 0.27_eb*qconv/((roomptr%width*roomptr%depth)**0.68_eb*roomptr%height**0.64_eb)
            if (qconv_avg>flxcv(i,iwall)) flxcv(i,iwall) = qconv_avg
        end if
        flwcv(i,ilay) = flwcv(i,ilay) - zzwarea(i,iwall)*flxcv(i,iwall)

    end do

    return
    end subroutine convection

! --------------------------- convective_flux -------------------------------------------

    subroutine convective_flux (iw,tg,tw,qdinl)

    !     routine: convective_flux
    !     purpose: calculate convective heat transfer for a wall segment. 
    !     arguments:  iw     wall number, standand cfast numbering convention
    !                 tg     temperature of gas layer adjacent to wall surface
    !                 tw     wall surface temperature
    !                 qdinl  convective flux into wall surface iw

    integer, intent(in) :: iw
    real(eb), intent(in) :: tg, tw
    real(eb), intent(out) :: qdinl
    
    real(eb) :: h
    
    if (iw<=2) then
        h = 1.52_eb*abs(tg - tw)**onethird
    else
        h = 1.31_eb*abs(tg - tw)**onethird
    end if
    
    qdinl = h * (tg - tw)
    return
    end subroutine convective_flux
    
 end module convection_routines
    