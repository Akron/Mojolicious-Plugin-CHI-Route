package Mojolicious::Plugin::CHI::Route;
use Mojo::Base 'Mojolicious::Plugin';

our $VERSION = 0.01;

sub register {
  my ($plugin, $app, $param) = @_;

  my $namespace = $param->{namespace} // 'default';

  $app->hook(
    after_render => sub {
      my ($c, $output, $format) = @_;

      # No cache instruction found
      return unless $c->stash('chi.cache');
      my $key = $c->stash('chi.cache');

      # Cache
      $c->chi($namespace)->set(
        $key => {
          body    => $$output,
          format  => $format,
          headers => $c->res->headers->to_hash(1)
        }
      );
    }
  );

  # Add condition to check for cache
  $app->routes->add_condition(
    chi => sub {
      my ($r, $c, $captures, $arg) = @_;

      my $key = 'xyz';
      if ($arg->{key}) {
        $key = $arg->{key}->($c);
      };

      # Get cache based on key
      my $found = $c->chi($namespace)->get($key);

      # Found cache! Render
      if ($found) {
        $c->render(
          format => $found->{format},
          data => $found->{body}
        );
        $c->res->headers->from_hash($found->{headers});
        $c->res->headers->header('X-FromCache' => 1);
        return 0;
      }

      # Render normally and then cache the route
      $c->stash('chi.cache' => $key);
      return 1;
    }
  );
};

1;
