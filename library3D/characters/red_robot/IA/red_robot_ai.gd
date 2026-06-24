class_name RedRobotAI
extends Node

## Inteligência artificial do Red Robot.
##
## Centraliza os COMPORTAMENTOS e as DECISÕES de ação do red_robot em tempo de execução.
## O "corpo" (red_robot.gd) é responsável por animação, física e disparo; ele instancia esta
## IA como filha e consulta as decisões aqui definidas a cada quadro:
##
##   1. Cadência de tiro: a recarga (do 1º e dos próximos tiros) fica `fire_rate_multiplier`
##      vezes mais rápida — ver `reload_time()`.
##   2. Engajamento: começa a atirar no player quando a distância é menor que o alcance da
##      arma e maior que `flee_distance` — ver `decide()` (Action.ENGAGE).
##   3. Recuo: se o player chegar a `flee_distance` metros ou menos, o robô corre no sentido
##      oposto OLHANDO para o player e continua atirando — ver `decide()` (Action.FLEE).

## Ações que a IA pode decidir para o corpo executar.
enum Action {
	APPROACH,  ## Fora do alcance da arma: aproxima-se do player.
	ENGAGE,    ## Dentro do alcance e além de `flee_distance`: mira e atira (avançando).
	FLEE,      ## Player perto demais: corre no sentido oposto olhando p/ player, atirando.
}

## Recarga 1.5x mais rápida (1º e próximos tiros): reload = recarga_base / multiplicador.
@export var fire_rate_multiplier: float = 1.5
## Se o player chegar a esta distância (m) ou menos, o robô recua atirando (Action.FLEE).
@export var flee_distance: float = 10.0
## Velocidade (m/s) com que o robô corre para longe do player ao recuar.
@export var flee_speed: float = 6.0


## Recarga efetiva: `base_wait` acelerada por `fire_rate_multiplier` (1.5x mais rápida).
func reload_time(base_wait: float) -> float:
	return base_wait / maxf(fire_rate_multiplier, 0.01)


## Decide a ação do quadro a partir da distância ao player e do alcance da arma:
## - player perto demais (<= flee_distance)            -> FLEE (recua atirando)
## - player no alcance e além de flee_distance         -> ENGAGE (atira)
## - player fora do alcance                            -> APPROACH (aproxima)
func decide(distance: float, effective_range: float) -> Action:
	if distance <= flee_distance:
		return Action.FLEE
	if distance <= effective_range:
		return Action.ENGAGE
	return Action.APPROACH
