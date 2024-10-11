import random
from abc import ABC

from evolutionary.config import Config
from evolutionary.crossover import single_point_cross, day_cross
from evolutionary.school_plan import SchoolPlan


class CrossoverStrategy(ABC):
    def crossover(self, parents: list, best_plan: SchoolPlan, size: int, config: Config):
        pass


class RouletteSinglePointCrossover(CrossoverStrategy):
    def crossover(self, parents: list, best_plan: SchoolPlan, size: int, config: Config):
        children = []
        if config.elitism:
            children.append(best_plan)

        crossover_rate = config.cross_params["crossover_rate"]
        groups = list(config.subjects.keys())
        sum_fitness = sum([plan.fitness for plan in parents])
        probabilities = [plan.fitness / sum_fitness for plan in parents]

        while len(children) < size:
            parent1, parent2 = random.choices(parents, probabilities, k=2)
            if random.random() < crossover_rate:
                child_plan = single_point_cross(parent1.plans, parent2.plans, groups, config.subjects)
                if child_plan is not None:
                    child = SchoolPlan(groups, child_plan)
                    children.append(child)
        return children


class RouletteDayCrossover(CrossoverStrategy):
    def crossover(self, parents: list, best_plan: SchoolPlan, size: int, config: Config):
        children = []
        if config.elitism:
            children.append(best_plan)

        crossover_rate = config.cross_params["crossover_rate"]
        groups = list(config.subjects.keys())
        sum_fitness = sum([plan.fitness for plan in parents])
        probabilities = [plan.fitness / sum_fitness for plan in parents]

        while len(children) < size:
            parent1, parent2 = random.choices(parents, probabilities, k=2)
            if random.random() < crossover_rate:
                child_plan = day_cross(parent1.plans, parent2.plans, groups, config.subjects)
                if child_plan is not None:
                    child = SchoolPlan(groups, child_plan)
                    children.append(child)
        return children


class ChampionCrossover(CrossoverStrategy):
    def crossover(self, parents: list, best_plan: SchoolPlan, size: int, config: Config):
        children = []
        if config.elitism:
            children.append(best_plan)

        crossover_rate = config.cross_params["crossover_rate"]
        groups = list(config.subjects.keys())

        while len(children) < size:
            parent2 = random.choice(parents)
            if random.random() < crossover_rate:
                child_plan = single_point_cross(best_plan.plans, parent2.plans, groups, config.subjects)
                if child_plan is not None:
                    child = SchoolPlan(groups, child_plan)
                    children.append(child)
        return children


class Generation:
    def __init__(self, config: Config, purge=False):
        self.gen_no: int = 0
        self.size: int = config.population_size
        self.config: Config = config
        self.purge: bool = purge
        self.population: list = []
        for _ in range(self.size):
            plan = SchoolPlan(config.subjects.keys())
            plan.generate(config)
            self.population.append(plan)

    def evaluate(self):
        for plan in self.population:
            plan.evaluate(self.config)
            # print(f"Evaluated plan; fitness: {plan.fitness}")
        self.population.sort(key=lambda x: x.fitness, reverse=True)

    def best_plan(self) -> SchoolPlan:
        return max(self.population, key=lambda x: x.fitness)

    def all(self):
        return [plan.as_dict() for plan in self.population]

    def statistics(self) -> dict:
        return {
            "max": self.best_plan().fitness,
            "avg": sum([plan.fitness for plan in self.population]) / self.size,
            "min": self.population[-1].fitness
        }

    def crossover(self, strategy: CrossoverStrategy = RouletteSinglePointCrossover()):
        # selection
        self.population.sort(key=lambda x: x.fitness)
        best_plan = self.best_plan()
        parents = self.population[: self.size // 2]

        # crossover
        self.population = strategy.crossover(parents, best_plan, self.size, self.config)
        self.gen_no += 1

        # purge worst plans
        if self.purge:  # FIXME: this is not working
            self.purge_worst(0.4 * sum([plan.fitness for plan in self.population]) / self.size)

    def mutate(self):
        for i in range(self.size - 1):
            if random.random() < self.config.cross_params["mutation_rate"]:
                self.population[i].swap(4)

    def purge_worst(self, min_limit: float):
        self.population = [plan for plan in self.population if plan.fitness >= min_limit]
        purges = self.size - len(self.population)
        print(f"Purged {purges} worst plans")
        for _ in range(purges):
            plan = SchoolPlan(self.config.subjects.keys())
            plan.generate(self.config)
            self.population.append(plan)
