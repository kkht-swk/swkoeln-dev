# Adanced Custom Fields Pro

Hinweis: ACF Pro ist kommerziell - man muss den Plugin-Folder des Produktvisystems manuell in die Entwicklungsumgebung kopieren, damit es funktioniert

Manchmal ist es in der Entwicklung hilfreich, auf die Tools von ACF zuzugreifen, um sich das anzuschauen und eine Konfig zu erzeugen und dann nach PHP auszugeben. Daher ist in der Entwicklungsumgebung  das ACF Menu in den Einstellungen verfübar, aber nicht in der Produktionssumgebung (siehe `functions.php`).
```
  if ( wp_get_environment_type() === 'production' ) {
      // Only allow fields to be edited on development
      add_filter( 'acf/settings/show_admin', '__return_false' );
  }
```

Damit man die PHP Konfig in die DB bekommt, gibt es in der Entwicklungsumgebung zusätzlich das Plugin `acf-php-to-json.php`
