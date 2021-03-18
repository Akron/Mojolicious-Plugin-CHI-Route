package Mojolicious::Plugin::CHI::Route;
use Mojo::Base 'Mojolicious::Plugin';

our $VERSION = 0.01;

sub register {
  my ($plugin, $app, $param) = @_;

  my $namespace = $param->{namespace} // 'default';

  # Set default key
  my $default_key = $param->{key} // sub {
    return shift->req->url->to_abs->to_string;
  };

  $app->hook(
    after_render => sub {
      my ($c, $output, $format) = @_;

      # No cache instruction found
      return unless $c->stash('chi.cache');

      # Only cache successfull renderings
      if ($c->res->is_error || ($c->stash('status') && $c->stash('status') != 200)) {
        return;
      };

      # Get key from stash
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

      # Only cache GET requests
      return 1 if $c->req->method ne 'GET';

      # Get the key for the cache
      my $key;

      # Set by argument
      if ($arg->{key}) {
        $key = ref $arg->{key} ? $arg->{key}->($c) : $arg->{key} . '';
      }

      # Set
      else {
        $key = $default_key->($c);
      };

      # Get cache based on key
      my $found = $c->chi($namespace)->get($key);

      # Found cache! Render
      if ($found) {
        $c->render(
          format => $found->{format},
          data => $found->{body}
        );

        for ($c->res) {
          $_->headers->from_hash($found->{headers});
          $_->headers->header('X-From-Cache' => 1);
          $_->code(200);
        };

        $c->stash->{'mojo.routed'} = 1;
        $c->helpers->log->debug('Routing to a cache');

        # Skip to final
        $c->match->position(1000);
      }

      # Render normally and then cache the route
      else {
        $c->stash('chi.cache' => $key);
      };

      return 1;
    }
  );
};


1;

__END__

=pod

=head1 SYNOPSIS


  use Mojolicious::Lite;

  plugin 'CHI::Route';

  get '/foo' => chi => sub {
    shift->render(text => 'This will be cached next time!');
  }

=head1 Description

In case the key is found in the cache, the cache will be returned.

The document will only be cached if it was a successful (200) GET request.
