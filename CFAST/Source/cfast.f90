
! --------------------------- cfast -------------------------------------------

    program cfast

    !     Routine: cfast (main program)
    !     Purpose: main program for the model

    !     Permission is hereby granted, free of charge, to any person
    !     obtaining a copy of this software and associated documentation
    !     files (the "Software"), to deal in the Software without
    !     restriction, including without limitation the rights to use,
    !     copy, modify, merge, publish, distribute, sublicense, and/or sell
    !     copies of the Software, and to permit persons to whom the
    !     Software is furnished to do so, subject to the following
    !     conditions:

    !     The above copyright notice and this permission notice shall be
    !     included in all copies or substantial portions of the Software.

    !     The software is provided "as is", without warranty of any kind,
    !     express or implied, including but not limited to the warranties
    !     of merchantability, fitness for a particular purpose and
    !     noninfringement. In no event shall the authors or copyright
    !     holders be liable for any claim, damages or other liability,
    !     whether in an action of contract, tort or otherwise, arising
    !     from, out of or in connection with the software or the use or
    !     other dealings in the software.   
    
    use precision_parameters
    use initialization_routines, only : initialize_memory, initialize_fire_objects, initialize_species, initialize_walls
    use input_routines, only : open_files, read_solver_ini, read_input_file
    use output_routines, only: output_version, output_initial_conditions
    use solve_routines, only : solve_simulation
    use utility_routines, only : cptime, read_command_options
    
    use cfast_main
    use cshell
    use iofiles
    use thermp
    use opt, only: total_steps
    
    implicit none

    real(eb) :: xdelt, tstop, tbeg, tend

    version = 7100        ! Current CFAST version number

    if(command_argument_count().eq.0)then
        call output_version(0)
        stop
    endif

    !     initialize the basic memory configuration

    call initialize_memory
    call initialize_fire_objects
    call read_command_options     
    call open_files

    mpsdat(1) = rundat(1)
    mpsdat(2) = rundat(2)
    mpsdat(3) = rundat(3)

    call output_version (logerr)

    call read_solver_ini
    call read_input_file

    call initialize_species

    xdelt = nsmax/deltat
    itmmax = xdelt + 1
    tstop = itmmax - 1

    ! add the default thermal property
    maxct = maxct + 1

    nlist(maxct) = 'DEFAULT'
    lnslb(maxct) = 1
    lfkw(1,maxct) = 0.120_eb
    lcw(1,maxct) = 900.0_eb
    lrw(1,maxct) = 800.0_eb
    lflw(1,maxct) = 0.0120_eb
    lepw(maxct) = 0.90_eb

    call initialize_walls (tstop)

    stime = 0.0_eb
    itmstp = 1
    xdelt = nsmax/deltat
    itmmax = xdelt + 1
    tstop = itmmax - 1

    call output_initial_conditions

    call cptime(tbeg)
    call solve_simulation (tstop)
    call cptime(tend)

    write (logerr,5000) tend - tbeg
    write (logerr,5010) total_steps
    call cfastexit ('CFAST', 0)

5000 format ('Total execution time = ',1pg10.3,' seconds')
5010 format ('Total time steps = ',i10)  
     
    end program cfast
    
! --------------------------- cfastexit -------------------------------------------

    subroutine cfastexit (name, errorcode)

    !     routine: cfastexit
    !     purpose: routine is called when CFAST exits, printing an error code if necessary
    !     arguments: name - routine name calling for exit ... at this point, it's always "CFAST"
    !                errorcode - numeric code indicating reason for an error exit.  0 for a normal exit

    use output_routines, only : deleteoutputfiles
    use cshell
    use iofiles, only: stopfile

    character, intent(in) :: name*(*)
    integer, intent(in) :: errorcode

    if (errorcode==0) then
        write(logerr, '(''Normal exit from '',a)') trim(name)
    else
        write(logerr,'(''***Error exit from '',a,'' code = '',i0)') trim(name), errorcode
    endif
    
    close (unit=4, status='delete')
    call deleteoutputfiles (stopfile)

    stop

    end subroutine cfastexit

