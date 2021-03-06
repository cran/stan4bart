# ===========================================================================
#          https://www.gnu.org/software/autoconf-archive/ax_ext.html
# ===========================================================================
#
# SYNOPSIS
#
#   AX_EXT_SSE2
#
# DESCRIPTION
#
#   Modified version of AX_EXT to only detect SSE2. Original description
#   below:
#
#   Find supported SIMD extensions by requesting cpuid. When a SIMD
#   extension is found, the -m"simdextensionname" is added to SIMD_FLAGS if
#   compiler supports it. For example, if "sse2" is available then "-msse2"
#   is added to SIMD_FLAGS.
#
#   Find other supported CPU extensions by requesting cpuid. When a
#   processor extension is found, the -m"extensionname" is added to
#   CPUEXT_FLAGS if compiler supports it. For example, if "bmi2" is
#   available then "-mbmi2" is added to CPUEXT_FLAGS.
#
#   This macro calls:
#
#     AC_SUBST(SIMD_FLAGS)
#     AC_SUBST(CPUEXT_FLAGS)
#
#   And defines:
#
#     HAVE_RDRND / HAVE_BMI1 / HAVE_BMI2 / HAVE_ADX / HAVE_MPX
#     HAVE_PREFETCHWT1 / HAVE_ABM / HAVE_MMX / HAVE_SSE / HAVE_SSE2
#     HAVE_SSE3 / HAVE_SSSE3 / HAVE_SSE4_1 / HAVE_SSE4_2 / HAVE_SSE4a
#     HAVE_SHA / HAVE_AES / HAVE_AVX / HAVE_FMA3 / HAVE_FMA4 / HAVE_XOP
#     HAVE_AVX2 / HAVE_AVX512_F / HAVE_AVX512_CD / HAVE_AVX512_PF
#     HAVE_AVX512_ER / HAVE_AVX512_VL / HAVE_AVX512_BW / HAVE_AVX512_DQ
#     HAVE_AVX512_IFMA / HAVE_AVX512_VBMI / HAVE_ALTIVEC / HAVE_VSX
#
# LICENSE
#
#   Copyright (c) 2007 Christophe Tournayre <turn3r@users.sourceforge.net>
#   Copyright (c) 2013,2015 Michael Petch <mpetch@capp-sysware.com>
#   Copyright (c) 2017 Rafael de Lucena Valle <rafaeldelucena@gmail.com>
#
#   Copying and distribution of this file, with or without modification, are
#   permitted in any medium without royalty provided the copyright notice
#   and this notice are preserved. This file is offered as-is, without any
#   warranty.

#serial 18

AC_DEFUN([AX_EXT],
[
  AC_REQUIRE([AC_CANONICAL_HOST])
  AC_REQUIRE([AC_PROG_CC])

  CPUEXT_FLAGS=""
  SIMD_FLAGS=""

  case $host_cpu in
    i[[3456]]86*|x86_64*|amd64*)

      AC_REQUIRE([AX_GCC_X86_CPUID])
      AC_REQUIRE([AX_GCC_X86_CPUID_COUNT])
      AC_REQUIRE([AX_GCC_X86_AVX_XGETBV])

      eax_cpuid0=0
      AX_GCC_X86_CPUID(0x00000000)
      if test "$ax_cv_gcc_x86_cpuid_0x00000000" != "unknown";
      then
        eax_cpuid0=`echo $ax_cv_gcc_x86_cpuid_0x00000000 | cut -d ":" -f 1`
      fi

      ecx_cpuid1=0
      edx_cpuid1=0
      if test "$((0x$eax_cpuid0))" -ge 1 ; then
        AX_GCC_X86_CPUID(0x00000001)
        if test "$ax_cv_gcc_x86_cpuid_0x00000001" != "unknown";
        then
          ecx_cpuid1=`echo $ax_cv_gcc_x86_cpuid_0x00000001 | cut -d ":" -f 3`
          edx_cpuid1=`echo $ax_cv_gcc_x86_cpuid_0x00000001 | cut -d ":" -f 4`
        fi
      fi

      AC_CACHE_VAL([ax_cv_have_mmx_os_support_ext],
      [
        ax_cv_have_mmx_os_support_ext=yes
      ])

      ax_cv_have_none_os_support_ext=yes

      AC_CACHE_VAL([ax_cv_have_sse_os_support_ext],
      [
        ax_cv_have_sse_os_support_ext=no,
        if test "$((0x$edx_cpuid1>>25&0x01))" = 1; then
          AC_LANG_PUSH([C])
          AC_RUN_IFELSE([AC_LANG_SOURCE([[
#include <signal.h>
#include <stdlib.h>
            /* No way at ring1 to ring3 in protected mode to check the CR0 and CR4
               control registers directly. Execute an SSE instruction.
               If it raises SIGILL then OS doesn't support SSE based instructions */
            void sig_handler(int signum){ exit(1); }
            int main(){
              signal(SIGILL, sig_handler);
              /* SSE instruction xorps  %xmm0,%xmm0 */
              __asm__ __volatile__ (".byte 0x0f, 0x57, 0xc0");
              return 0;
            }]])],
            [ax_cv_have_sse_os_support_ext=yes],
            [ax_cv_have_sse_os_support_ext=no],
            [ax_cv_have_sse_os_support_ext=no])
          AC_LANG_POP([C])
        fi
      ])

      for ac_instr_info dnl
      in "sse;sse2;SSE2;edx_cpuid1,26;-msse2;HAVE_SSE2;SIMD_FLAGS" dnl
         #
      do ac_instr_os_support=$(eval echo \$ax_cv_have_$(echo $ac_instr_info | cut -d ";" -f 1)_os_support_ext)
         ac_instr_acvar=$(echo $ac_instr_info | cut -d ";" -f 2)
         ac_instr_shortname=$(echo $ac_instr_info | cut -d ";" -f 3)
         ac_instr_chk_loc=$(echo $ac_instr_info | cut -d ";" -f 4)
         ac_instr_chk_reg=0x$(eval echo \$$(echo $ac_instr_chk_loc | cut -d "," -f 1))
         ac_instr_chk_bit=$(echo $ac_instr_chk_loc | cut -d "," -f 2)
         ac_instr_compiler_flags=$(echo $ac_instr_info | cut -d ";" -f 5)
         ac_instr_have_define=$(echo $ac_instr_info | cut -d ";" -f 6)
         ac_instr_flag_type=$(echo $ac_instr_info | cut -d ";" -f 7)

         AC_CACHE_CHECK([whether ${ac_instr_shortname} is supported by the processor], [ax_cv_have_${ac_instr_acvar}_cpu_ext],
         [
           eval ax_cv_have_${ac_instr_acvar}_cpu_ext=no
           if test "$((${ac_instr_chk_reg}>>${ac_instr_chk_bit}&0x01))" = 1 ; then
             eval ax_cv_have_${ac_instr_acvar}_cpu_ext=yes
           fi
         ])

         if test x"$(eval echo \$ax_cv_have_${ac_instr_acvar}_cpu_ext)" = x"yes"; then
           AC_CACHE_CHECK([whether ${ac_instr_shortname} is supported by the processor and OS], [ax_cv_have_${ac_instr_acvar}_ext],
           [
             eval ax_cv_have_${ac_instr_acvar}_ext=no
             if test x"${ac_instr_os_support}" = x"yes"; then
               eval ax_cv_have_${ac_instr_acvar}_ext=yes
             fi
           ])

           if test "$(eval echo \$ax_cv_have_${ac_instr_acvar}_ext)" = yes; then
             AX_CHECK_COMPILE_FLAG(${ac_instr_compiler_flags}, eval ax_cv_support_${ac_instr_acvar}_ext=yes,
                                                               eval ax_cv_support_${ac_instr_acvar}_ext=no)
             if test x"$(eval echo \$ax_cv_support_${ac_instr_acvar}_ext)" = x"yes"; then
               eval ${ac_instr_flag_type}=\"\$${ac_instr_flag_type} ${ac_instr_compiler_flags}\"
               AC_DEFINE_UNQUOTED([${ac_instr_have_define}])
             else
               AC_MSG_WARN([Your processor and OS supports ${ac_instr_shortname} instructions but not your compiler, can you try another compiler?])
             fi
           else
             if test x"${ac_instr_os_support}" = x"no"; then
               AC_CACHE_VAL(ax_cv_support_${ac_instr_acvar}_ext, eval ax_cv_support_${ac_instr_acvar}_ext=no)
               AC_MSG_WARN([Your processor supports ${ac_instr_shortname}, but your OS doesn't])
             fi
           fi
         else
           AC_CACHE_VAL(ax_cv_have_${ac_instr_acvar}_ext, eval ax_cv_have_${ac_instr_acvar}_ext=no)
           AC_CACHE_VAL(ax_cv_support_${ac_instr_acvar}_ext, eval ax_cv_support_${ac_instr_acvar}_ext=no)
         fi
      done
  ;;
  esac

  AH_TEMPLATE([HAVE_SSE2],[Define to 1 to support Streaming SIMD Extensions])
])
