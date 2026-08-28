<?php

namespace App\Services\Menu;

class MenuValidationResult
{
    /** @var array<int, array{menuId:int, issues:array<int, MenuValidationIssue>}> */
    private array $menus = [];

    /** @var array<int, MenuValidationIssue> */
    private array $collectionIssues = [];

    public function noAssignedMenu(): void
    {
        $this->collectionIssues[] = new MenuValidationIssue('NO_ASSIGNED_MENU', 'error', 'No actively assigned menus are available for publishing.', 'menu_collection', null, 0);
    }

    public function begin(int $menuId): void
    {
        $this->menus[$menuId] ??= ['menuId' => $menuId, 'issues' => []];
    }

    public function add(MenuValidationIssue $issue): void
    {
        $this->begin($issue->menuId);
        $this->menus[$issue->menuId]['issues'][] = $issue;
    }

    public function toArray(): array
    {
        $issues = collect($this->collectionIssues)->concat(collect($this->menus)->flatMap(fn (array $menu) => $menu['issues']));
        $by = fn (string $severity) => $issues->filter(fn (MenuValidationIssue $issue) => $issue->severity === $severity)->values()->map->toArray()->all();
        $menus = collect($this->menus)->map(function (array $menu): array {
            $issues = collect($menu['issues']);

            return ['menuId' => $menu['menuId'], 'isValid' => $issues->where('severity', 'error')->isEmpty(), 'errorCount' => $issues->where('severity', 'error')->count(), 'warningCount' => $issues->where('severity', 'warning')->count(), 'informationCount' => $issues->where('severity', 'information')->count(), 'issues' => $issues->map->toArray()->values()->all()];
        })->values()->all();
        $errors = $by('error');
        $warnings = $by('warning');
        $information = $by('information');

        return ['isValid' => $errors === [], 'errorCount' => count($errors), 'warningCount' => count($warnings), 'informationCount' => count($information), 'errors' => $errors, 'warnings' => $warnings, 'information' => $information, 'menus' => $menus];
    }
}
