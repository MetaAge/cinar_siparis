protected $routeMiddleware = [
    // diğerleri
    'role' => \App\Http\Middleware\RoleMiddleware::class,
];
protected $middleware = [
    // ...
    \App\Http\Middleware\AddImageHeaders::class,
];