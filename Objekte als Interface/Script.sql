/* Script zur Dokumentation der Objekthierarchie */
create sequence bankanweisung_seq;

-- Abstrakter Obertyp
create or replace type bankanweisung
  authid definer
as object(
  id number,
  iban char(34 byte),
  bic varchar2(11 byte),
  empfaenger varchar2(50 char),
  betrag number,
  -- ...
  member procedure speichern(
    self in out nocopy bankanweisung),
  member function get_iban
    return varchar2,
  member function get_bic_11
    return varchar2,
  member procedure signieren(
    self in out nocopy bankanweisung),
  member procedure anweisen(
    self in out nocopy bankanweisung),
  member procedure widerrufen(
    self in out nocopy bankanweisung,
    p_grund in varchar2)
  -- ...
) not final not instantiable
/

-- Implementierung der Funktionalitaet des Obertyps
create or replace type body bankanweisung
as
  member function get_iban
    return varchar2
  as
  begin
    return regexp_replace(
             self.iban, 
             '([[:alnum:]]{4})([[:digit:]]{4})([[:digit:]]{4})([[:digit:]]{4})([[:digit:]]{4})([[:digit:]]{2})',
             '\1 \2 \3 \4 \5 \6');
  end get_iban;
  
  member function get_bic_11
    return varchar2
  as
  begin
    return rpad(self.bic, 11, 'X');
  end get_bic_11;
  
  member procedure speichern(
    self in out nocopy bankanweisung)
  as
  begin
    null;
  end speichern;
  
  member procedure signieren(
    self in out nocopy bankanweisung)
  as
  begin
    null;
    -- alternativ: raise_application_error(-20000, 'Anweisung kann/darf nicht signiert werden');
  end signieren;
  
  member procedure anweisen(
    self in out nocopy bankanweisung)
  as
  begin
    null;
    -- alternativ: raise_application_error(-20000, 'Anweisung kann/darf nicht angewiesen werden');
  end anweisen;
  
  member procedure widerrufen(
    self in out nocopy bankanweisung,
    p_grund in varchar2)
  as
  begin
    null;
    -- alternativ: raise_application_error(-20000, 'Anweisung kann/darf nicht gesperrt werden');
  end widerrufen;
end;
/

-- Geschaeftslogik fuer den konkreten Typ UEBERWEISUNG
-- Hilfspackage zur Validierung spezieller Werte
create or replace package bl_pruefung
  authid definer
as
  function pruefe_iban(
    p_iban in varchar2)
    return varchar2;
    
  function pruefe_bic(
    p_bic in varchar2)
    return varchar2;
end bl_pruefung;
/


create or replace package body bl_pruefung
as
  function pruefe_iban(
    p_iban in varchar2)
    return varchar2
  as
    -- Ausfuehrliche Pruefung internationaler IBAN gem. https://de.wikipedia.org/wiki/IBAN#Zusammensetzung
    c_regex_de constant varchar2(200) := '^(DE[[:digit:]]{2})([[:digit:]]{4})([[:digit:]]{4})([[:digit:]]{4})([[:digit:]]{4})([[:digit:]]{2})$';
    l_iban number;
  begin
    -- Mustervergleich
    if not regexp_like(p_iban, c_regex_de) then
      raise_application_error(-20000, 'IBAN nicht korrekt');
    end if;
    -- Pruefziffer testen
    l_iban := to_number(substr(p_iban, 5));
    l_iban := l_iban * 100 + (ascii(substr(p_iban, 1, 1)) - 55);
    l_iban := l_iban * 100 + (ascii(substr(p_iban, 2, 1)) - 55);
    l_iban := l_iban * 100 + to_number(substr(p_iban, 3, 2));
    l_iban := l_iban mod 97;

    if l_iban is null or l_iban <> 1 then 
      raise_application_error(-2e4, 'IBAN-Pruefziffer ungueltig');
    end if; 
    return p_iban;
  end pruefe_iban;
  
  function pruefe_bic(
    p_bic in varchar2)
    return varchar2
  as
    -- Beispielpruefung
    c_regex_de constant varchar2(200) := '([a-zA-Z]{6}[a-zA-Z0-9]{5})?';
  begin
    if not regexp_like(p_bic, c_regex_de) then
      raise_application_error(-20000, 'BIC nicht korrekt');
    end if;
    return p_bic;
  end pruefe_bic;
end bl_pruefung;
/

-- Tabelle zur Aufnahme der Ueberweisungen
create table ueberweisung_tab(
  ueb_id number,
  ueb_iban varchar2(34 byte),
  ueb_bic varchar2(11 byte),
  ueb_empfaenger varchar2(50 char),
  ueb_betrag number,
  ueb_erstellt_am date,
  constraint pk_ueberweisung primary key(ueb_id)
) organization index;


-- Package zur Aufnahme der Geschaeftslogik des konkreten Typen
create or replace package ueberweisung_pkg
  authid definer
as

  procedure speichern(
    p_self in out nocopy ueberweisung);
    
  procedure signieren(
    p_self in out nocopy ueberweisung);

  procedure anweisen(
    p_self in out nocopy ueberweisung);

  procedure widerrufen(
    p_self in out nocopy ueberweisung,
    p_grund in varchar2);
    
end ueberweisung_pkg;
/


create or replace package body ueberweisung_pkg 
as

  procedure speichern(
    p_self in out nocopy ueberweisung)
  as
  begin
    -- Speicherlogik wird im Regelfall Objekt auf relationale Tabelle abbilden:
    merge into ueberweisung_tab t
    using (select p_self ueb
             from dual) s
       on (t.ueb_id = s.ueb.id)
     when matched then update set
          ueb_iban = s.ueb.iban,
          ueb_bic = s.ueb.bic,
          ueb_empfaenger = s.ueb.empfaenger,
          ueb_betrag = s.ueb.betrag
     when not matched then insert(ueb_id, ueb_iban, ueb_bic, ueb_empfaenger, ueb_betrag, ueb_erstellt_am)
          values(s.ueb.id, s.ueb.iban, s.ueb.bic, s.ueb.empfaenger, s.ueb.betrag, sysdate);
    dbms_output.put_line('Speichern-Anforderung eingegangen');
  end speichern;

  procedure signieren(
    p_self in out nocopy ueberweisung) 
  as
  begin
    -- TODO: Implementierung für procedure UEBERWEISUNG_PKG.signieren erforderlich
    dbms_output.put_line('Signieren-Anforderung eingegangen');
  end signieren;

  procedure anweisen(
    p_self in out nocopy ueberweisung) 
  as
  begin
    -- TODO: Implementierung für procedure UEBERWEISUNG_PKG.anweisen erforderlich
    dbms_output.put_line('Anweisen-Anforderung eingegangen');
    null;
  end anweisen;

  procedure widerrufen(
    p_self in out nocopy ueberweisung,
    p_grund in varchar2) 
  as
  begin
    -- TODO: Implementierung für procedure UEBERWEISUNG_PKG.widerrufen erforderlich
    dbms_output.put_line('Widerrufen-Anforderung eingegangen');
    null;
  end widerrufen;

end ueberweisung_pkg;
/


-- Nun kann der konkrete Typ implementiert werden. Die eigentliche Arbeit wird im 
-- zuvor angelegten Package gemacht, das Objekt dient nur als Erweiterung um ein Interface
create or replace type UEBERWEISUNG under BANKANWEISUNG(
  overriding member procedure speichern(
    self in out nocopy ueberweisung),
  overriding member procedure signieren(
    self in out nocopy ueberweisung),
  overriding member procedure anweisen(
    self in out nocopy ueberweisung),
  overriding member procedure widerrufen(
    self in out nocopy ueberweisung,
    p_grund in varchar2),
  constructor function ueberweisung(
    self in out nocopy ueberweisung,
    p_iban in varchar2,
    p_bic in varchar2 default null,
    p_empfaenger in varchar2,
    p_betrag in number)
    return self as result
) not final;
/


create or replace type body ueberweisung
as
  overriding member procedure speichern(
    self in out nocopy ueberweisung)
  as
  begin
    ueberweisung_pkg.speichern(self);
  end speichern;
  
  overriding member procedure signieren(
    self in out nocopy ueberweisung)
  as
  begin
    ueberweisung_pkg.signieren(self);
  end signieren;
  
  overriding member procedure anweisen(
    self in out nocopy ueberweisung)
  as
  begin
    ueberweisung_pkg.anweisen(self);
  end anweisen;
  
  overriding member procedure widerrufen(
    self in out nocopy ueberweisung,
    p_grund in varchar2)
  as
  begin
    ueberweisung_pkg.widerrufen(self, p_grund);
  end widerrufen;
  
  constructor function ueberweisung(
    self in out nocopy ueberweisung,
    p_iban in varchar2,
    p_bic in varchar2 default null,
    p_empfaenger in varchar2,
    p_betrag in number)
    return self as result
  as
  begin
    -- Pattern einer Konstruktorfunktion:
    self.id := bankanweisung_seq.nextval;
    self.iban := bl_pruefung.pruefe_iban(p_iban);
    self.bic := bl_pruefung.pruefe_bic(p_bic);
    self.empfaenger := p_empfaenger;
    self.betrag := p_betrag;
    return;
  end ueberweisung;
  
end;
/


/*  Verwendung des Objekts */
-- In SQL
  with ueberweisung as(
       select ueberweisung('DE23476234987263498270', 'ABCDEF45', 'Peter Schmitz', 123.45) objekt
         from dual)
select u.objekt.id, u.objekt.get_iban() iban, u.objekt.get_bic_11() bic
  from ueberweisung u;
  
-- Falsche Pruefziffer:
select ueberweisung('DE23476234987263498279', 'ABCDEF45', 'Peter Schmitz', 123.45) objekt
  from dual;
  

-- Im Code kann auf Obertyp agiert werden:
create or replace procedure anweisen_bankanweisung(
  p_anweisung in out nocopy bankanweisung)
as
begin
  p_anweisung.anweisen();
end;
/

set serveroutput on

declare
  l_ueberweisung ueberweisung;
  l_betrag number := 123.45; -- Vermeidung von Konvertierungsproblem im Konstruktor
begin
  l_ueberweisung := ueberweisung('DE23476234987263498270', 'ABCDEF45', 'Peter Schmitz', l_betrag);
  anweisen_bankanweisung(l_ueberweisung);
  l_ueberweisung.speichern;
end;
/

select *
  from ueberweisung_tab;
  
rollback;
