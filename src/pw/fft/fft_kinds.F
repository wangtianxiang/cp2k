!--------------------------------------------------------------------------------------------------!
!   CP2K: A general program to perform molecular dynamics simulations                              !
!   Copyright 2000-2025 CP2K developers group <https://cp2k.org>                                   !
!                                                                                                  !
!   SPDX-License-Identifier: GPL-2.0-or-later                                                      !
!--------------------------------------------------------------------------------------------------!

! **************************************************************************************************
!> \brief Defines the basic variable types
!> \author Teodoro Laino - 01.2011
! **************************************************************************************************

MODULE fft_kinds

   IMPLICIT NONE
   PRIVATE
   INTEGER, PARAMETER, PUBLIC :: wp = SELECTED_REAL_KIND(14, 200)
   INTEGER, PARAMETER, PUBLIC :: dp = SELECTED_REAL_KIND(14, 200)
   INTEGER, PARAMETER, PUBLIC :: sp = SELECTED_REAL_KIND(6, 30)

END MODULE fft_kinds
