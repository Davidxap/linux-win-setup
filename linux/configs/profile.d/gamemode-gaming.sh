# GameMode siempre activo en sesiones
# Para juegos nativos:     el wrapper de Steam usa LD_PRELOAD=libgamemodeauto.so.0
# Para juegos Proton/Wine:  PROTON_ENABLE_GAMEMODE=1 en el entorno
export PROTON_ENABLE_GAMEMODE=1
