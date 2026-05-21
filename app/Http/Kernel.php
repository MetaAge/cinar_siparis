protected $routeMiddleware = [
    // diğerleri
    'role' => \App\Http\Middleware\RoleMiddleware::class,
];
protected $middleware = [
    // ...
    \App\Http\Middleware\AddImageHeaders::class,
];
protected $middlewareGroups = [
    'api' => [
        \Laravel\Sanctum\Http\Middleware\EnsureFrontendRequestsAreStateful::class,
        \Illuminate\Routing\Middleware\SubstituteBindings::class,
        \Fruitcake\Cors\HandleCors::class, // 🔥 BURADA OLMALI
    ],
];