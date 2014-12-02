class Avatar < Asset

  has_attached_file :attachment, {
      :styles => {:medium => "300x300>", :thumb => "100x100>"},
      :default_url => "/assets/missing.png",
  }

end