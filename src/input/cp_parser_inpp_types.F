!--------------------------------------------------------------------------------------------------!
!   CP2K: A general program to perform molecular dynamics simulations                              !
!   Copyright 2000-2025 CP2K developers group <https://cp2k.org>                                   !
!                                                                                                  !
!   SPDX-License-Identifier: GPL-2.0-or-later                                                      !
!--------------------------------------------------------------------------------------------------!

! **************************************************************************************************
!> \brief a module to allow simple internal preprocessing in input files.
!> \par History
!>      - standalone proof-of-concept implementation (20.02.2008,AK)
!>      - integration into cp2k (22.02.2008,tlaino)
!>      - variables added (25.02.2008,AK)
!> \author Axel Kohlmeyer [AK] - CMM/UPenn Philadelphia
!> \date 25.02.2008
! **************************************************************************************************
MODULE cp_parser_inpp_types

   USE kinds, ONLY: default_path_length
#include "../base/base_uses.f90"

   IMPLICIT NONE
   PRIVATE

   TYPE inpp_type
      ! for '@INCLUDE "some_file.inc"'
      ! currently open include file stack pointer
      INTEGER                              :: io_stack_level = 0
      ! include file stack data
      INTEGER, POINTER, DIMENSION(:)       :: io_stack_channel => NULL(), &
                                              io_stack_lineno => NULL()
      CHARACTER(len=default_path_length), &
         POINTER, DIMENSION(:)             :: io_stack_filename => NULL()
      ! for '@SET VAR value' and '${VAR}'
      ! table size
      INTEGER                              :: num_variables = 0
      ! table entries
      CHARACTER(len=default_path_length), &
         POINTER, DIMENSION(:)       :: variable_name => NULL()
      CHARACTER(len=default_path_length), &
         POINTER, DIMENSION(:)       :: variable_value => NULL()
   END TYPE inpp_type

   PUBLIC :: inpp_type, create_inpp_type, release_inpp_type
   CHARACTER(len=*), PARAMETER, PRIVATE :: moduleN = 'cp_parser_inpp_types'

CONTAINS

! ****************************************************************************
!> \brief creates the internal preprocessing type
!> \param inpp ...
!> \param initial_variables ...
!> \date  22.02.2008
!> \author Teodoro Laino [tlaino] - University of Zurich
! **************************************************************************************************
   SUBROUTINE create_inpp_type(inpp, initial_variables)
      TYPE(inpp_type), POINTER                           :: inpp
      CHARACTER(len=default_path_length), &
         DIMENSION(:, :), POINTER                        :: initial_variables

      CPASSERT(.NOT. ASSOCIATED(inpp))
      ALLOCATE (inpp)

      IF (ASSOCIATED(initial_variables)) THEN
         inpp%num_variables = SIZE(initial_variables, 2)
         ALLOCATE (inpp%variable_name(inpp%num_variables))
         inpp%variable_name = initial_variables(1, :)
         ALLOCATE (inpp%variable_value(inpp%num_variables))
         inpp%variable_value = initial_variables(2, :)
      END IF

   END SUBROUTINE create_inpp_type

! ****************************************************************************
!> \brief releases the internal preprocessing type
!> \param inpp ...
!> \date  22.02.2008
!> \author Teodoro Laino [tlaino] - University of Zurich
! **************************************************************************************************
   SUBROUTINE release_inpp_type(inpp)
      TYPE(inpp_type), POINTER                           :: inpp

      CPASSERT(ASSOCIATED(inpp))

      IF (ASSOCIATED(inpp%io_stack_channel)) THEN
         DEALLOCATE (inpp%io_stack_channel)
      END IF
      IF (ASSOCIATED(inpp%io_stack_lineno)) THEN
         DEALLOCATE (inpp%io_stack_lineno)
      END IF
      IF (ASSOCIATED(inpp%io_stack_filename)) THEN
         DEALLOCATE (inpp%io_stack_filename)
      END IF

      IF (ASSOCIATED(inpp%variable_name)) THEN
         DEALLOCATE (inpp%variable_name)
      END IF
      IF (ASSOCIATED(inpp%variable_value)) THEN
         DEALLOCATE (inpp%variable_value)
      END IF

      DEALLOCATE (inpp)
   END SUBROUTINE release_inpp_type

END MODULE cp_parser_inpp_types
