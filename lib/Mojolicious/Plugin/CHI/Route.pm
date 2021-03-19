package Mojolicious::Plugin::CHI::Route;
use Mojo::Base 'Mojolicious::Plugin';

our $VERSION = "0.01";

# Register plugin
sub register {
  my ($plugin, $app, $param) = @_;

  # Plugin parameter
  $param ||= {};

  # Load parameter from Config file
  if (my $config_param = $app->config('CHI-Route')) {
    $param = { %$param, %$config_param };
  };

  # Load CHI plugin if not already loaded
  unless (exists $app->renderer->helpers->{chi}) {
    $app->plugin('CHI');
  };

  # set namespace
  my $namespace = $param->{namespace}   // 'default';

  unless ($app->chi($namespace)) {
    $app->log->error("No cache defined for '$namespace'");

    # Add condition to check for cache
    $app->routes->add_condition(
      chi => sub { 1 }
    );

    return;
  }

  my $expires_in = $param->{expires_in} // '6 hour';

  # Set default key
  my $default_key = $param->{key} // sub {
    return shift->req->url->to_abs->to_string;
  };

  # Cache if required
  $app->hook(
    after_render => sub {
      my ($c, $output, $format) = @_;

      # No cache instruction found
      return unless $c->stash('chi.r.cache');

      # Only cache successfull renderings
      if ($c->res->is_error || ($c->stash('status') && $c->stash('status') != 200)) {
        return;
      };

      # Get key from stash
      my $key = $c->stash('chi.r.cache');

      # Delete Mojolicious server header
      my $headers = $c->res->headers->to_hash(1);
      $headers->{Server} = [];

      # Cache
      $c->chi($namespace)->set(
        $key => {
          'body'    => $$output,
          'format'  => $format,
          'headers' => $headers
        } => {
          expires_in => $c->stash('chi.r.expires') // $expires_in
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

      my $chi = $c->chi($namespace);

      # No cache associated
      return 1 unless $chi;

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
      my $found = $chi->get($key);

      # Found cache! Render
      if ($found) {
        $c->render(
          'format' => $found->{format},
          'data'   => $found->{body}
        );

        for ($c->res) {
          $_->headers->from_hash($found->{headers});
          $_->headers->header('X-Cache-CHI' => 1);
          $_->code(200);
        };

        $c->stash->{'mojo.routed'} = 1;
        $c->helpers->log->debug('Routing to a cache');

        # Skip to final
        $c->match->position(1000);
      }

      # Render normally and then cache the route
      else {

        if (exists $arg->{expires_in}) {
          $c->stash('chi.r.expires' => $arg->{expires_in});
        };

        $c->stash('chi.r.cache' => $key);
      };

      return 1;
    }
  );
};


1;

__END__

=pod

=encoding utf8

=head1 NAME

Mojolicious::Plugin::CHI::Route - Cache renderings based on routes

=head1 SYNOPSIS

  # Mojolicious
  $app->plugin('CHI::Route');
  $app->routes->get('/foo')->requires('chi')->to(
    cb => sub {
      shift->render(
        text => 'This will be served from cache next time!'
      );
    }
  )

  # Mojolicious::Lite
  use Mojolicious::Lite;

  plugin 'CHI::Route';

  get '/foo' => (chi => { expires_in => '5 hours' }) => sub {
    shift->render(
      text => 'This will be served from cache next time!'
    );
  }

=head1 DESCRIPTION

L<Mojolicious::Plugin::CHI::Route> enables caching on the router level
by using L<Mojolicious::Plugin::CHI>.

=head1 METHODS

=head2 register

Called when registering the plugin.

The registration accepts the following parameters:

=over 2

=item key

The default key callback for all routes.
Defaults to the absolute URL of the request.

=item namespace

Define the L<CHI> namespace for the cached renderings.
Defaults to C<default>.
It is beneficial to use a separate namespace to easily
L<purge|Mojolicious::Plugin::CHI/chi purge> or
L<clear|Mojolicious::Plugin::CHI/chi clear>
just the route cache on updates.

=item expires_in

The default lifetime of route cache entries.
Can be either a number of seconds or a
L<duration expression|CHI/DURATION EXPRESSIONS>.
Defaults to C<6 hours>.

=back

All parameters can be set as part of the configuration
file with the key C<CHI-Route> or on registration
(that can be overwritten by configuration).


=head1 CONDITIONS

=head2 chi

The caching works by adding a condition to the route,
that will either render from cache or cache a dynamic rendering.
The condition will always succeed.
Only successfull C<GET> requests will be cached.

=over 2

=item key

The key for the cache.
Accepts either a callback to dynamically define the key or
a string (e.g. for non-dynamic routes without placeholders).
This overrides the default C<key> configuration value.

In case the key is found in the cache, the cache content will be returned.

=item expires_in

The lifetime of the route cache entry.
Can be either a number of seconds or a
L<duration expression|CHI/DURATION EXPRESSIONS>.
This overrides the default C<expires_in> configuration value.

=back

=head1 TROUBLESHOOTING

The cached results will contain a C<X-Cache-CHI> header.

=head1 AVAILABILITY

  https://github.com/Akron/Mojolicious-Plugin-CHI-Route


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2021, L<Nils Diewald|https://www.nils-diewald.de/>.

This program is free software, you can redistribute it
and/or modify it under the terms of the Artistic License version 2.0.

=cut
