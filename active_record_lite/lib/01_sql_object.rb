require_relative 'db_connection'
require 'active_support/inflector'
require_relative '02_searchable.rb'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject


  def self.columns
    return @columns unless @columns.nil?
    columns = DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        #{table_name}
    SQL

    @columns = columns.first.map(&:to_sym)
  end

  def self.finalize!
    self.columns.each do |col|
      define_method("#{col}=") do |val|
        self.attributes[col] = val
      end
      define_method(col) { self.attributes[col] }
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name ||= self.to_s.tableize
  end

  def self.all
    data = DBConnection.execute(<<-SQL)
      SELECT
        *
      FROM
        #{table_name}
    SQL
    parse_all(data)
  end

  def self.parse_all(results)
    results.map { |hash| self.new(hash) }
  end

  def self.find(id)
    result = DBConnection.execute(<<-SQL)
      SELECT
        *
      FROM
        #{table_name}
      WHERE
        id = #{id}
      LIMIT
        1
    SQL
    result.empty? ? nil : parse_all(result).first
  end

  def initialize(params = {})
    self.class.finalize!
    params.each do |k, v|
      raise "unknown attribute \'#{k}\'" unless self.class.columns.include?(k.to_sym)
      send("#{k}=", v)
    end
  end

  def attributes
    @attributes ||= {}
    @attributes
  end

  def attribute_values
    self.class.columns.map { |attr| self.send(attr) }
    # attributes.values
  end

  def insert
    columns = self.class.columns.drop(1)
    col_names = columns.map(&:to_s).join(", ")
    question_marks = (["?"] * columns.length).join(",")
    DBConnection.execute(<<-SQL, *attribute_values.drop(1))
      INSERT INTO
        #{self.class.table_name} (#{col_names})
      VALUES
        (#{question_marks})
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def update
    set_line = self.class.columns.map { |attr| "#{attr} = ?" }.join(", ")
    DBConnection.execute(<<-SQL, *attribute_values, id)
      UPDATE
        #{self.class.table_name}
      SET
        #{set_line}
      WHERE
        #{self.class.table_name}.id = ?
    SQL
  end

  def save
    id ? update : insert
  end
end
