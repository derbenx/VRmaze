This is a procedurally generated 3D maze runs stand alone.. It can work with PCVR, but will run on PC.
If you want the full expierence of someone insulting you as you run the maze you'll need:

A copy of an AI GGUF, maybe this one: https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/tree/main
Any Q4 GGUF should do fine, if you have less then 6gb of vram, just pick the smallest one.
(pretty much any GGUF AI will work, there are smaller ones too. Some might be excessivvely chatty though, like SMOL)

A copy of llama.cpp to let the GGUF model work: https://github.com/ggml-org/llama.cpp/releases
Pick what one matches your PC. If you have less then 6gb vram, "x64 CPU" might be your best bet.
if you have at least 6gb vram and a nvidia card, "x64 CUDA 13" "CUDA 13 DLL" (you need both files)

Download the release of the compiled version, click releases on the right. (Unless you really want to grab the code and try to figure that out.)

extract all of the gemma AI and llama stuff into a folder. Make a bat file containing:

<code> .\llama-server.exe -m gemma-4-E4B-it-UD-Q8_K_XL.gguf --reasoning off --frequency-penalty 0.5 --repeat-penalty 1.18 --temp 0.88 </code>

** remember to substitute the right filename for your version of gemma in there.

Run the bat file to start the AI server. Run the extracted godot game on the same PC.
They should find each other automatically and your game should start insulting you right away!

WADS to move around, mouse to look.
Q/E to climb up/down.
alt+enter for full screen.
