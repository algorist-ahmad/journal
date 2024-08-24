# A wrapper program for jrnl.sh

I'm unsatsified with how jrnl works. This program fine-tunes how jrnl work by adding some safeguards
and making jrnl more accident-resistant as well as <u>**amnesia**-resistant</u> which is often my
problem with any software.

## Problem

jrnl writes anything that isn't a valid option to a journal. This is awful design, as it often leads to accidental writes.\
My solution would be to prevent any writing commands by guarding them with a switch, like ```-w``` or ```--write```.
Instead of writing to a journal, erroneous commands should display the correct options to use.

I tend to forget how my own commands work. I imagine it would be worse for someone who isn't familiar with my
commands. So as a solution, every command should suggest an additional option for the user' s information.
This feature could be turned off for users that prefer a clean output.
